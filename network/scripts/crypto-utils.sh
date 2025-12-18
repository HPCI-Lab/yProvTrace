#!/bin/bash

source common.sh

# ============================================================================
# Cryptographic Material Utility Functions
# ============================================================================

generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH} > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "Error while generating crypto material using config: ${CRYPTO_CONFIG_FILE}"
        exit 1
    fi

    log_success "Crypto material generated for organization: ${ORG_DOMAIN}"
}

generate_ccp() {

    # * Assumes that organization is loaded

    local type=${ORG_TYPE}

    if [ "$type" == "orderer" ]; then
        log_info "Skipping CCP generation for orderer organization."
        return
    fi

    local hostname="${ORG_HOSTNAME}.${ORG_DOMAIN}"
    local listen_address="${ORG_ENDPOINT}:${ORG_LISTEN_PORT}"
    local ids_dir=$(get_identity_dir)
    local org_cert_path="${ids_dir}/msp/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem" # Before was private pointing to peer0
    local org_ccp_file="${ids_dir}/connection-${ORG_NAME,,}.json"

    sed -e "s|\${ORG_NAME}|$ORG_NAME|" \
        -e "s|\${MSPID}|$ORG_MSP_ID|" \
        -e "s|\${PEER_HOSTNAME}|$hostname|" \
        -e "s|\${ENDPOINT}|$listen_address|" \
        -e "s|\${ORG_CERT_PATH}|$org_cert_path|" \
        ${NETWORK_TMP_PATH}/ccp-template.json > $org_ccp_file

    if [ $? -ne 0 ]; then
        log_error "Failed to generate ccp for organization: ${ORG_NAME}"
        exit 1
    fi

    log_success "CCP generated successfully for: ${ORG_NAME}"
}

delete_crypto() {

    # * Assumes that organization is loaded

    local org_dir=$(get_org_dir)
    rm -rf "${org_dir}"

    if [ $? -ne 0 ]; then
        log_error "Failed to delete cryptographic material for organization: ${ORG_DOMAIN}"
        exit 1
    fi

    log_success "Cryptographic material for organization ${ORG_DOMAIN} deleted successfully."
}


