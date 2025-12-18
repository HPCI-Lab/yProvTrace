#!/bin/bash

. common.sh

copy_msp_folder() {

    # * Assumes that organization is loaded 

    local domain=${ORG_DOMAIN}
    local type=${ORG_TYPE}

    local org_dir=$(get_org_dir)
    local ids_dir=$(get_identity_dir)

    if [ ! -d "${ids_dir}" ]; then
        mkdir -p "${ids_dir}"
        log_debug "Created identities directory: ${ids_dir}"
    fi

    # Copy the MSP folder containting TLS and CA certificates
    cp -rf "${org_dir}/msp" "${ids_dir}/msp"

    # Copy the admin certificate into MSP folder
    cp "${org_dir}/users/Admin@${domain}/msp/signcerts/Admin@${domain}-cert.pem" "${ids_dir}/msp/admincerts/admin-cert.pem"

    if [[ "$type" == "orderer" ]]; then
        # Copy the orderer TLS server certificate
        mkdir -p "${ids_dir}/tls"
        cp "${org_dir}/orderers/orderer.${domain}/tls/server.crt" "${ids_dir}/tls/server.crt" # Assumes standard naming for orderers
    fi

    log_success "MSP/TLS folders shared for organization: ${ORG_DOMAIN}"
}

generate_endpoints() {
    
    # * Assumes that organization is loaded

    local ids_dir=$(get_identity_dir)

    if [ ! -d "${ids_dir}" ]; then
        mkdir -p "${ids_dir}"
        log_debug "Created identities directory: ${ids_dir}"
    fi

    local json_file="${ids_dir}/endpoints.json"
    echo "{}" > "${json_file}"

    jq \
        --arg id "service" \
        --arg hostname "$ORG_HOSTNAME" \
        --arg domain "$ORG_DOMAIN" \
        --arg listenAddress "${ORG_ENDPOINT}:${ORG_LISTEN_PORT}" \
        '.[$id] = {hostname: $hostname, domain: $domain, address: $listenAddress}' \
        "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"

    if [[ "$ORG_TYPE" == "orderer" ]]; then
        jq \
            --arg id "service" \
            --arg adminAddress "${ORG_ENDPOINT}:${ORG_ADMIN_PORT}" \
            '.[$id].adminAddress = $adminAddress' \
            "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
    fi

    log_success "Endpoints generated for: ${ORG_HOSTNAME}.${ORG_DOMAIN}"
}

verify_identity() {

    # * Assumes that organization is loaded

    local org_dir=$(get_org_dir)
    local ids_dir=$(get_identity_dir)
    local admin_private_key="${org_dir}/users/Admin@${ORG_DOMAIN}/msp/keystore/priv_sk"
    local admin_public_cert="${ids_dir}/msp/admincerts/admin-cert.pem"
    
    if [ ! -f "${admin_public_cert}" ]; then
        log_error "Admin public certificate for ${ORG_DOMAIN} not found."
        exit 1
    fi

    if [ ! -f "${admin_private_key}" ]; then
        log_error "Admin private key for ${ORG_DOMAIN} not found."
        exit 1
    fi

    # Create the challenge and signature
    CHALLENGE=$(openssl rand -hex 32)
    SIGNATURE=$(echo -n "$CHALLENGE" | openssl dgst -sha256 -sign "${admin_private_key}" | base64)

    openssl x509 -in "${admin_public_cert}" -pubkey -noout | openssl dgst -sha256 -verify /dev/stdin -signature <(echo "$SIGNATURE" | base64 -d) <(echo -n "$CHALLENGE")

    if [[ $? -ne 0 ]]; then
        log_error "Identity verification failed for ${ORG_DOMAIN}."
        exit 1
    fi
}

get_tls_identities() {

    # * Assumes that network paths are set

    for organization in $(ls -d ${NETWORK_IDS_PATH}/peerOrganizations/*/); do
        local domain=$(basename "${organization}")
        local peer_address=$(jq -r '.[].address' "${organization}/endpoints.json" | head -n 1)
        local tls_root_cert_file=${organization}msp/tlscacerts/tlsca.${domain}-cert.pem

        echo "--peerAddresses ${peer_address} --tlsRootCertFiles ${tls_root_cert_file}"
    done
}

remove_identity() {

    # * Assumes that organization is loaded

    local org_dir=$(get_org_dir)
    rm -rf "${org_dir}"

    if [ $? -ne 0 ]; then
        log_error "Failed to delete cryptographic material for organization: ${ORG_DOMAIN}"
        exit 1
    fi

    log_success "Cryptographic material deleted for organization: ${ORG_DOMAIN}"
}