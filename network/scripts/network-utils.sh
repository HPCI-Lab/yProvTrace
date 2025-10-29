#!/bin/bash

. set-env.sh

CURRENT=${NETWORK_CHN_PATH}/config.json
MODIFIED=${NETWORK_CHN_PATH}/modified_config.json

generate_genesis() {
    configtxgen \
        -configPath ${NETWORK_CTX_PATH} \
        -profile ChannelUsingRaft \
        -outputBlock ${GENESIS_BLOCK} \
        -channelID ${NETWORK_CHN_NAME}

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create genesis block. Check ${NETWORK_LOG_PATH}/join/genesis.log for details."
        exit 1
    else
        echo "Genesis block created successfully at ${GENESIS_BLOCK}"
    fi
}

join_orderer() {
    local ord_hostname=$1
    set_orderer ${ord_hostname}
    osnadmin channel join \
        --channelID ${NETWORK_CHN_NAME} \
        --config-block ${GENESIS_BLOCK} \
        -o ${ORDERER_ADMIN_ADDRESS} \
        --ca-file ${ORDERER_TLS_CA} \
        --client-cert ${ORDERER_TLS_SIGN_CERT} \
        --client-key ${ORDERER_TLS_PRIVATE_KEY}
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to join orderer ${ORDERER_HOSTNAME} to channel '${NETWORK_CHN_NAME}'."
        exit 1
    else
        echo "Orderer ${ORDERER_HOSTNAME} joined channel '${NETWORK_CHN_NAME}' successfully."
    fi
}

join_organization() {

    local org_domain=$1
    local endpoints_file="${NETWORK_IDS_PATH}/peerOrganizations/${org_domain}/endpoints.json"

    if [ ! -f "${endpoints_file}" ]; then
        echo "Error: Endpoints file not found for organization '${org_domain}'."
        exit 1
    fi

    local peers_count=$(jq -r "keys | length" ${endpoints_file})

    for ((i=1; i<=peers_count; i++)); do
        set_peer ${org_domain} ${i}
        peer channel join -b ${GENESIS_BLOCK}

        if [ $? -ne 0 ]; then
            echo "Error: Failed to join peer ${CORE_PEER_ADDRESS} to channel '${NETWORK_CHN_NAME}'."
            exit 1
        else
            echo "Peer ${CORE_PEER_ADDRESS} joined channel '${NETWORK_CHN_NAME}' successfully."
        fi
    done
}

generate_definition() {

    local configtx_file=$1

    if [ -z "${configtx_file}" ]; then
        echo "Usage: $0 <configtx_file>"
        exit 1
    fi

    if [ ! -f "${configtx_file}" ]; then
        echo "Error: Configtx file '${configtx_file}' does not exist."
        exit 1
    fi

    local org_name=$(yq -r '.Organizations[0].Name' ${configtx_file})
    local org_msp_id=$(yq -r '.Organizations[0].ID' ${configtx_file})
    local target_dir=$(yq -r '.Organizations[0].MSPDir' ${configtx_file})
    local definition_file="$(dirname ${target_dir#../})/${org_name,,}.json"

    configtxgen -configPath $(dirname ${configtx_file}) -printOrg ${org_name} > ${definition_file}

    echo "${definition_file}"
}

fetch_channel_config() {

    local org_domain=$1

    set_orderer ${DEFAULT_ORD}
    set_peer ${org_domain} ${DEFAULT_PEER_ID}

    echo "Fetching the most recent configuration block for the channel"
    peer channel fetch config ${NETWORK_CHN_PATH}/config_block.pb \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        -c ${NETWORK_CHN_NAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA}

    echo "Decoding config block to JSON and isolating config to ${CURRENT}"
    configtxlator proto_decode \
        --input ${NETWORK_CHN_PATH}/config_block.pb \
        --type common.Block \
        --output ${NETWORK_CHN_PATH}/config_block.json

    jq .data.data[0].payload.data.config ${NETWORK_CHN_PATH}/config_block.json > "${CURRENT}"
}

create_update_transaction() {

    local org_name=$1

    if [ -z "${org_name}" ]; then
        echo "Usage: $0 <organization_name>"
        exit 1
    fi

    # Encode the current configuration in protobuf format
    configtxlator proto_encode \
        --input "${CURRENT}" \
        --type common.Config \
        --output ${NETWORK_CHN_PATH}/current_config.pb

    # Encode the modified configuration in protobuf format
    configtxlator proto_encode \
        --input "${MODIFIED}" \
        --type common.Config \
        --output ${NETWORK_CHN_PATH}/modified_config.pb

    # Compute the config update between the original and modified configurations
    configtxlator compute_update \
        --channel_id "${NETWORK_CHN_NAME}" \
        --original ${NETWORK_CHN_PATH}/current_config.pb \
        --updated ${NETWORK_CHN_PATH}/modified_config.pb \
        --output ${NETWORK_CHN_PATH}/config_update.pb

    # Decode the config update to JSON format
    configtxlator proto_decode \
        --input ${NETWORK_CHN_PATH}/config_update.pb \
        --type common.ConfigUpdate \
        --output ${NETWORK_CHN_PATH}/config_update.json

    echo '{"payload":{"header":{"channel_header":{"channel_id":"'${NETWORK_CHN_NAME}'", "type":2}},"data":{"config_update":'$(cat ${NETWORK_CHN_PATH}/config_update.json)'}}}' | jq . > ${NETWORK_CHN_PATH}/config_update_in_envelope.json

    # Encode the config update in envelope format
    configtxlator proto_encode \
        --input ${NETWORK_CHN_PATH}/config_update_in_envelope.json \
        --type common.Envelope \
        --output ${NETWORK_CHN_PATH}/${org_name,,}_update_in_envelope.pb
}

sign_update_transaction() {
    local update_transaction=$1
    local org_domain=$2
    set_peer ${org_domain} ${DEFAULT_PEER_ID}
    peer channel signconfigtx -f ${update_transaction}

    if [ $? -ne 0 ]; then
        echo "Error: Failed to sign the update transaction."
        exit 1
    else
        echo "Update transaction signed successfully."
    fi
}

commit_update_transaction() {
    local update_transaction=$1
    local org_domain=$2
    set_orderer ${DEFAULT_ORD}
    set_peer ${org_domain} ${DEFAULT_PEER_ID}
    peer channel update \
        -f ${update_transaction} \
        -c ${NETWORK_CHN_NAME} \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA}
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to commit the update transaction to channel '${NETWORK_CHN_NAME}'."
        exit 1
    else
        echo "Update transaction committed to channel '${NETWORK_CHN_NAME}' successfully."

        rm ${NETWORK_CHN_PATH}/*.json
        rm ${NETWORK_CHN_PATH}/*.pb
    fi
}

set_anchor_peer() {

    local org_domain=$1
    local peer_id=$2
    local endpoints_file="${NETWORK_IDS_PATH}/peerOrganizations/${org_domain}/endpoints.json"

    if [ ! -f "${endpoints_file}" ]; then
        echo "Error: Endpoints file not found for organization '${org_domain}'."
        exit 1
    fi

    local peer=$(jq -r ".\"${peer_id}\"" ${endpoints_file})

    if [ -z "${peer}" ]; then
        echo "Error: Peer '${peer_id}' not found in endpoints file for organization '${org_domain}'."
        exit 1
    fi

    # Fetch the current channel configuration to add the anchor peer
    fetch_channel_config ${org_domain}

    # Set the first peer as the anchor peer
    PEER_HOSTNAME=$(echo $peer | jq -r '.hostname')
    PEER_PORT=$(echo $peer | jq -r '.address | split(":") | .[1]')
    PEER_MSPID=$(echo $peer | jq -r '.localMspId')
    ORG_NAME=$(echo $peer | jq -r '.localMspId | split("MSP") | .[0]')

    if [ $PEER_MSPID != $CORE_PEER_LOCALMSPID ]; then
        echo "Error: The peer's MSP ID does not match the current peer's MSP ID."
        exit 1
    fi

    jq '.channel_group.groups.Application.groups.'${ORG_NAME}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${PEER_HOSTNAME}'","port": '${PEER_PORT}'}]},"version": "0"}}' ${CURRENT} > ${MODIFIED}

    # Create the anchor peer update transaction
    create_update_transaction ${ORG_NAME}

    peer channel update \
        -f ${NETWORK_CHN_PATH}/${ORG_NAME,,}_update_in_envelope.pb \
        -c ${NETWORK_CHN_NAME} \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA}
    
    # Update the endpoints file, by setting anchor=true in the peer
    jq --arg peer_id "${peer_id}" '.[$peer_id].is_anchor = true' "${endpoints_file}" > "${endpoints_file}.tmp" && mv "${endpoints_file}.tmp" "${endpoints_file}"
    
    # Remove all the intermediary files, except for the genesis.block
    rm ${NETWORK_CHN_PATH}/*.json
    rm ${NETWORK_CHN_PATH}/*.pb
}