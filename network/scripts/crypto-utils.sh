#!/bin/bash

# ============================================================================
# yProvTrace: Cryptographic Material Utility Functions
# ============================================================================
# Description:
#   Provides utilities for generating, managing, and deleting cryptographic
#   materials (certificates, keys, MSP structures) for Fabric organizations.
#
# Key Operations:
#   1. Generate crypto material using cryptogen
#   2. Create connection profiles (CCP) for client applications
#   3. Clean up crypto material for organization removal
#
# Functions:
#   - generate_crypto() : Generate MSP and TLS certificates
#   - generate_ccp()    : Create connection profile JSON
#   - delete_crypto()   : Remove organization crypto material
#
# Dependencies:
#   - cryptogen      : Fabric tool for certificate generation
#   - common.sh      : Configuration and path management
#   - CCP template   : JSON template for connection profiles
# ============================================================================

source common.sh

# ----------------------------------------------------------------------------
# Generate Crypto Material
# ----------------------------------------------------------------------------
# Description: Generates MSP and TLS certificates for an organization
# Parameters:
#   $1 - Path to cryptogen configuration file (YAML)
# Purpose: Creates all necessary certificates and keys for organization
# Output: MSP structure in NETWORK_ORG_PATH directory
# Exit: 1 if generation fails
# ----------------------------------------------------------------------------
generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH} > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "Error while generating crypto material using config: ${CRYPTO_CONFIG_FILE}"
        exit 1
    fi

    log_success "Crypto material generated for organization: ${ORG_DOMAIN}"
}

# ----------------------------------------------------------------------------
# Generate Connection Profile (CCP)
# ----------------------------------------------------------------------------
# Description: Creates a connection profile for client application connections
# Purpose: Provides SDK-compatible JSON configuration for network access
# Output: connection-<orgname>.json in identity directory
# Note: Only generated for peer organizations (skipped for orderers)
# Template: Uses templates/ccp-template.json as base
# Exit: 1 if CCP generation fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Delete Crypto Material
# ----------------------------------------------------------------------------
# Description: Removes all cryptographic material for an organization
# Purpose: Clean up during organization removal or reset
# Note: Deletes entire organization directory from NETWORK_ORG_PATH
# Warning: This is a destructive operation - cannot be undone
# Exit: 1 if deletion fails
# ----------------------------------------------------------------------------
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


