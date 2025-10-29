#!/bin/bash

. set-env.sh

copy_msp_folder() {

    # Copy the MSP and TLS certificates
    # Also initialize the endpoints.json file for the identity

    local crypto_config_file=$1

    local org=$(yq -r '.PeerOrgs' ${crypto_config_file})
    local ord=$(yq -r '.OrdererOrgs' ${crypto_config_file})

    if [[ "$org" == "null" ]]; then
        type="ordererOrganizations"
        data=$(echo "$ord" | jq -r 'to_entries[0] | .value')
    else
        type="peerOrganizations"
        data=$(echo "$org" | jq -r 'to_entries[0] | .value')
    fi

    local name=$(echo "$data" | jq -r '.Name')
    local domain=$(echo "$data" | jq -r ".Domain")
    local hostname=$(echo "$data" | jq -r '.Specs[0].Hostname')

    ORG_DIR="${NETWORK_IDS_PATH}/${type}/${domain,,}"
    mkdir -p "${ORG_DIR}"

    # Copy the MSP folder containting TLS and CA certificates
    cp -rf "${NETWORK_ORG_PATH}/${type}/${domain}/msp" "${ORG_DIR}/msp"

    # Copy the admin certificate into MSP folder
    cp "${NETWORK_ORG_PATH}/${type}/${domain}/users/Admin@${domain}/msp/signcerts/Admin@${domain}-cert.pem" "${ORG_DIR}/msp/admincerts/admin-cert.pem"

    if [[ "$type" == "ordererOrganizations" ]]; then
        # Copy the orderer TLS server certificate
        mkdir -p "${ORG_DIR}/tls"
        cp "${NETWORK_ORG_PATH}/${type}/${domain}/orderers/${hostname}.${domain}/tls/server.crt" "${ORG_DIR}/tls/server.crt"
    fi

    echo ${ORG_DIR}
}

generate_endpoints() {
    
    local org_dir=$1
    local docker_compose_file=$2

    # Extract the endpoints from the docker compose file
    local services=$(yq -r '.services | to_entries | .[] | @json' ${docker_compose_file})
    local genesis_orgs=$(yq -r '.Organizations' "${NETWORK_CTX_PATH}/configtx.yaml")

    while IFS= read -r service; do

        local json_file="${org_dir}/endpoints.json"
        if [ ! -f "${json_file}" ]; then
            echo "{}" > "${json_file}"
        fi

        local service_id=$(($(jq 'keys | length' ${json_file}) + 1))
        local service_type=$(echo "$service" | jq -r '.value.image | split(":") | .[0] | split("/") | .[-1] | sub("fabric-"; "")') # This returns peer or orderer
        
        if [[ "$service_type" == "peer" ]]; then
            PEER_HOSTNAME=$(echo "$service" | jq -r '.key')
            PEER_GENERAL_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "") | split(":") | .[-1]')
            PEER_LISTEN_PORT="${DEFAULT_ENDPOINT}:${PEER_GENERAL_LISTEN_PORT}"
            PEER_LOCAL_MSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')

            # Check if the peer is an anchor peer
            local is_anchor=false
            while read -r org; do
                anchor=$(echo "$org" | jq -r --arg host "$PEER_HOSTNAME" '.AnchorPeers | .[]? | select(.Host == $host)')
                if [[ -n "$anchor" ]]; then
                    is_anchor=true
                    break
                fi
            done < <(echo "$genesis_orgs" | jq -c '.[]')

            jq \
                --arg peerId "$service_id" \
                --arg peerHost "$PEER_HOSTNAME" \
                --arg listenPort "$PEER_LISTEN_PORT" \
                --arg localMspId "$PEER_LOCAL_MSPID" \
                --arg is_anchor "$is_anchor" \
                '.[$peerId] = {hostname: $peerHost, address: $listenPort, localMspId: $localMspId, is_anchor: $is_anchor}' \
                "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
        
        elif [[ "$service_type" == "orderer" ]]; then
            ORDERER_HOSTNAME=$(echo "$service" | jq -r '.key')
            ORDERER_DOMAIN=$(echo "$ORDERER_HOSTNAME" | cut -d'.' -f2-)
            ORDERER_GENERAL_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
            ORDERER_LISTEN_ADDRESS="${DEFAULT_ENDPOINT}:${ORDERER_GENERAL_LISTEN_PORT}"
            ORDERER_ADMIN_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "") | split(":") | .[-1]')
            ORDERER_ADMIN_LISTEN_ADDRESS="${DEFAULT_ENDPOINT}:${ORDERER_ADMIN_LISTEN_PORT}"

            jq \
                --arg ordId "$service_id" \
                --arg ordHost "$ORDERER_HOSTNAME" \
                --arg ordDomain "$ORDERER_DOMAIN" \
                --arg listenAddress "$ORDERER_LISTEN_ADDRESS" \
                --arg adminListenAddress "$ORDERER_ADMIN_LISTEN_ADDRESS" \
                '.[$ordId] = {hostname: $ordHost, domain: $ordDomain, address: $listenAddress, adminAddress: $adminListenAddress}' \
                "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
        fi
    done <<< "$services"
}

verify_identity() {

    # Verify the identity of the caller by checking its private keys against the public certificates

    local org_domain=$1
    
    local admin_private_key="${NETWORK_ORG_PATH}/peerOrganizations/${org_domain}/users/Admin@${org_domain}/msp/keystore/priv_sk"
    if [ ! -f "${admin_private_key}" ]; then
        admin_private_key="${NETWORK_ORG_PATH}/ordererOrganizations/${org_domain}/users/Admin@${org_domain}/msp/keystore/priv_sk"
    fi
    
    local admin_public_cert="${NETWORK_IDS_PATH}/peerOrganizations/${org_domain}/msp/admincerts/admin-cert.pem"
    if [ ! -f "${admin_public_cert}" ]; then
        admin_public_cert="${NETWORK_IDS_PATH}/ordererOrganizations/${org_domain}/msp/admincerts/admin-cert.pem"
    fi
    
    if [ ! -f "${admin_public_cert}" ]; then
        echo "Error: Admin certificate for ${org_domain} not found."
        exit 1
    fi

    if [ ! -f "${admin_private_key}" ]; then
        echo "Error: Admin private key for ${org_domain} not found."
        exit 1
    fi

    # Create the challenge and signature
    CHALLENGE=$(openssl rand -hex 32)
    SIGNATURE=$(echo -n "$CHALLENGE" | openssl dgst -sha256 -sign "${admin_private_key}" | base64)

    openssl x509 -in "${admin_public_cert}" -pubkey -noout | openssl dgst -sha256 -verify /dev/stdin -signature <(echo "$SIGNATURE" | base64 -d) <(echo -n "$CHALLENGE")

    if [[ $? -ne 0 ]]; then
        echo "Error: unable to verify identity. Certificates mismatch."
        exit 1
    fi
}

get_tls_identities() {
    for organization in $(ls -d ${NETWORK_IDS_PATH}/peerOrganizations/*/); do
        local domain=$(basename "${organization}")
        local peer_address=$(jq -r '.[].address' "${organization}/endpoints.json" | head -n 1)
        local tls_root_cert_file=${organization}msp/tlscacerts/tlsca.${domain}-cert.pem

        echo "--peerAddresses ${peer_address} --tlsRootCertFiles ${tls_root_cert_file}"
    done
}

remove_identity() {
    local org_domain=$1
    rm -rf "${NETWORK_IDS_PATH}/peerOrganizations/${org_domain,,}"
}