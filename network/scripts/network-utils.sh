#!/bin/bash

source common.sh

CURRENT=${NETWORK_CHN_PATH}/config.json
MODIFIED=${NETWORK_CHN_PATH}/modified_config.json

# ============================================================================
# Network/Channel Utility Functions
# ============================================================================

generate_genesis() {

    local genesis_file=$(get_genesis_block)

    configtxgen \
        -configPath ${NETWORK_CTX_PATH} \
        -profile ChannelUsingRaft \
        -outputBlock ${genesis_file} \
        -channelID ${CHANNEL_NAME}

    if [ $? -ne 0 ]; then
        log_error "Failed to create genesis block"
        exit 1
    fi

    log_success "Genesis block created successfully at ${genesis_file}"
}

join_orderer() {
    set_orderer_env
    local genesis_file=$(get_genesis_block)

    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ${genesis_file} \
        -o ${ORDERER_ADMIN_ADDRESS} \
        --ca-file ${ORDERER_TLS_CA} \
        --client-cert ${ORDERER_TLS_SIGN_CERT} \
        --client-key ${ORDERER_TLS_PRIVATE_KEY}
    
    if [ $? -ne 0 ]; then
        log_error "Orderer ${ORDERER_HOSTNAME} failed to join channel '${CHANNEL_NAME}'."
        exit 1
    fi
    
    log_success "Orderer ${ORDERER_HOSTNAME} joined channel '${CHANNEL_NAME}' successfully."
}

join_peer() {
    set_peer_env
    local genesis_file=$(get_genesis_block)

    peer channel join -b ${genesis_file}

    if [ $? -ne 0 ]; then
        log_error "Peer ${CORE_PEER_ADDRESS} failed to join channel '${CHANNEL_NAME}'."
        exit 1
    fi
        
    log_success "Peer ${CORE_PEER_ADDRESS} joined channel '${CHANNEL_NAME}' successfully."
}

generate_definition() {

    local configtx_file=$1

    if [ -z "${configtx_file}" ]; then
        log_error "Configtx file is required to generate organization definition"
        exit 1
    fi

    if [ ! -f "${configtx_file}" ]; then
        log_error "Configtx file '${configtx_file}' does not exist"
        exit 1
    fi

    local org_name=$(yq -r '.Organizations[0].Name' ${configtx_file})
    local org_msp_id=$(yq -r '.Organizations[0].ID' ${configtx_file})
    local target_dir=$(yq -r '.Organizations[0].MSPDir' ${configtx_file})
    local definition_file="$(dirname ${target_dir#../})/${org_name,,}.json"

    configtxgen -configPath $(dirname ${configtx_file}) -printOrg ${org_name} > ${definition_file}

    if [ $? -ne 0 ]; then
        log_error "Failed to generate organization definition for '${org_name}'."
        exit 1
    fi

    echo "${definition_file}"
}

fetch_channel_config() {

    get_default_orderer
    set_peer_env

    log_debug "Fetching the most recent configuration block for the channel"
    peer channel fetch config ${NETWORK_CHN_PATH}/config_block.pb \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        -c ${CHANNEL_NAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA}

    if [ $? -ne 0 ]; then
        log_error "Failed to fetch the latest configuration block for channel '${CHANNEL_NAME}'"
        exit 1
    fi

    log_debug "Decoding config block to JSON and isolating config to ${CURRENT}"
    configtxlator proto_decode \
        --input ${NETWORK_CHN_PATH}/config_block.pb \
        --type common.Block \
        --output ${NETWORK_CHN_PATH}/config_block.json
    
    if [ $? -ne 0 ]; then
        log_error "Failed to decode configuration block for channel '${CHANNEL_NAME}'"
        exit 1
    fi

    jq .data.data[0].payload.data.config ${NETWORK_CHN_PATH}/config_block.json > "${CURRENT}"

    if [ $? -ne 0 ]; then
        log_error "Failed to isolate channel configuration for channel '${CHANNEL_NAME}'"
        exit 1
    fi

    log_success "Channel configuration for channel '${CHANNEL_NAME}' fetched successfully."
}

create_update_transaction() {

    local org_name=$1

    if [ -z "${org_name}" ]; then
        log_error "Organization name is required to create update transaction."
        exit 1
    fi

    # Encode the current configuration in protobuf format
    configtxlator proto_encode \
        --input "${CURRENT}" \
        --type common.Config \
        --output ${NETWORK_CHN_PATH}/current_config.pb
    
    if [ $? -ne 0 ]; then
        log_error "Failed to encode current configuration for channel '${CHANNEL_NAME}'."
        exit 1
    fi

    # Encode the modified configuration in protobuf format
    configtxlator proto_encode \
        --input "${MODIFIED}" \
        --type common.Config \
        --output ${NETWORK_CHN_PATH}/modified_config.pb
    
    if [ $? -ne 0 ]; then
        log_error "Failed to encode modified configuration for channel '${CHANNEL_NAME}'."
        exit 1
    fi

    # Compute the config update between the original and modified configurations
    configtxlator compute_update \
        --channel_id "${CHANNEL_NAME}" \
        --original ${NETWORK_CHN_PATH}/current_config.pb \
        --updated ${NETWORK_CHN_PATH}/modified_config.pb \
        --output ${NETWORK_CHN_PATH}/config_update.pb
    
    if [ $? -ne 0 ]; then
        log_error "Failed to compute configuration update for channel '${CHANNEL_NAME}'."
        exit 1
    fi

    # Decode the config update to JSON format
    configtxlator proto_decode \
        --input ${NETWORK_CHN_PATH}/config_update.pb \
        --type common.ConfigUpdate \
        --output ${NETWORK_CHN_PATH}/config_update.json
    
    if [ $? -ne 0 ]; then
        log_error "Failed to decode configuration update for channel '${CHANNEL_NAME}'."
        exit 1
    fi

    echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat ${NETWORK_CHN_PATH}/config_update.json)'}}}' | jq . > ${NETWORK_CHN_PATH}/config_update_in_envelope.json

    # Encode the config update in envelope format
    configtxlator proto_encode \
        --input ${NETWORK_CHN_PATH}/config_update_in_envelope.json \
        --type common.Envelope \
        --output ${NETWORK_CHN_PATH}/${org_name,,}_update_in_envelope.pb
    
    if [ $? -ne 0 ]; then
        log_error "Failed to encode configuration update envelope for channel '${CHANNEL_NAME}'."
        exit 1
    fi

    log_success "Update transaction for organization '${org_name}' created successfully."
}

sign_update_transaction() {

    local update_transaction=$1
    
    set_peer_env
    peer channel signconfigtx -f ${update_transaction}

    if [ $? -ne 0 ]; then
        log_error "Failed to sign the update transaction"
        exit 1
    fi

    log_success "Update transaction signed successfully"
}

commit_update_transaction() {
    local update_transaction=$1

    get_default_orderer
    set_peer_env

    peer channel update \
        -f ${update_transaction} \
        -c ${CHANNEL_NAME} \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA}
    
    if [ $? -ne 0 ]; then
        log_error "Failed to commit update transaction to channel '${CHANNEL_NAME}'"
        exit 1
    fi

    rm ${NETWORK_CHN_PATH}/*.json
    rm ${NETWORK_CHN_PATH}/*.pb

    log_success "Update transaction committed to channel '${CHANNEL_NAME}' successfully."
}

set_anchor_peer() {

    set_peer_env

    # Fetch the current channel configuration to add the anchor peer
    fetch_channel_config

    jq '.channel_group.groups.Application.groups.'${ORG_NAME}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${ORG_ENDPOINT}'","port": '${ORG_LISTEN_PORT}'}]},"version": "0"}}' ${CURRENT} > ${MODIFIED}

    # Create the anchor peer update transaction
    create_update_transaction ${ORG_NAME}

    local update_transaction="${NETWORK_CHN_PATH}/${ORG_NAME,,}_update_in_envelope.pb"

    commit_update_transaction ${update_transaction}

    log_success "Anchor peer for organization '${ORG_NAME}' set successfully."
}