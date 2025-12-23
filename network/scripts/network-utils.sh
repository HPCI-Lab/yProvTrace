#!/bin/bash

# ============================================================================
# yProvTrace: Network & Channel Utility Functions
# ============================================================================
# Description:
#   Core utilities for Hyperledger Fabric channel operations including
#   genesis block generation, member joins, configuration updates, and
#   anchor peer management.
#
# Key Operations:
#   1. Channel initialization (genesis block)
#   2. Node joining (orderers and peers)
#   3. Dynamic membership (add/remove organizations)
#   4. Anchor peer configuration
#   5. Configuration update workflow
#
# Functions:
#   - generate_genesis()          : Create channel genesis block
#   - join_orderer()              : Add orderer to channel
#   - join_peer()                 : Add peer to channel
#   - generate_definition()       : Create org definition from configtx
#   - fetch_channel_config()      : Retrieve current channel config
#   - create_update_transaction() : Build config update transaction
#   - sign_update_transaction()   : Sign configuration update
#   - commit_update_transaction() : Submit update to orderer
#   - set_anchor_peer()           : Configure anchor peer for org
#
# Configuration Files:
#   CURRENT  : Current channel configuration (JSON)
#   MODIFIED : Modified channel configuration (JSON)
# ============================================================================

source common.sh

CURRENT=${NETWORK_CHN_PATH}/config.json
MODIFIED=${NETWORK_CHN_PATH}/modified_config.json

# ----------------------------------------------------------------------------
# Generate Genesis Block
# ----------------------------------------------------------------------------
# Description: Creates the genesis block for the application channel
# Purpose: Initializes channel with founding members and policies
# Output: genesis.block in NETWORK_CHN_PATH
# Exit: 1 if genesis block creation fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Join Orderer to Channel
# ----------------------------------------------------------------------------
# Description: Adds orderer node to channel consensus cluster
# Authentication: TLS client certificates
# Purpose: Enables orderer to participate in channel consensus
# Exit: 1 if join operation fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Join Peer to Channel
# ----------------------------------------------------------------------------
# Description: Adds peer node to channel
# Purpose: Enables peer to maintain ledger and execute chaincode
# Requirement: Organization must be in channel configuration
# Exit: 1 if join operation fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Generate Organization Definition
# ----------------------------------------------------------------------------
# Description: Creates organization definition from configtx file
# Parameters:
#   $1 - Path to organization's configtx.yaml
# Output: JSON file with organization MSP, policies, and endpoints
# Returns: Path to generated definition file
# Exit: 1 if generation fails
# ----------------------------------------------------------------------------
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
    local definition_file="$(dirname "$(realpath "$target_dir")")/${org_name,,}.json"

    configtxgen -configPath "$(dirname "$(realpath "$configtx_file")")" -printOrg ${org_name} > ${definition_file}

    if [ $? -ne 0 ]; then
        log_error "Failed to generate organization definition for '${org_name}'."
        exit 1
    fi

    echo "${definition_file}"
}

# ----------------------------------------------------------------------------
# Fetch Channel Configuration
# ----------------------------------------------------------------------------
# Description: Retrieves and decodes current channel configuration
# Process:
#   1. Fetch latest config block from orderer
#   2. Decode protobuf to JSON
#   3. Extract configuration payload
# Output: Stores decoded config in CURRENT (config.json)
# Purpose: Required before creating configuration updates
# Exit: 1 if fetch or decode fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Create Configuration Update Transaction
# ----------------------------------------------------------------------------
# Description: Generates config update transaction from current/modified configs
# Parameters:
#   $1 - Organization name (used in output filename)
# Process:
#   1. Encode current config to protobuf
#   2. Encode modified config to protobuf
#   3. Compute delta (update) between them
#   4. Wrap update in envelope for signing
# Output: <orgname>_update_in_envelope.pb
# Exit: 1 if any encoding or computation step fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Sign Configuration Update Transaction
# ----------------------------------------------------------------------------
# Description: Adds organization's signature to config update
# Parameters:
#   $1 - Path to update transaction envelope
# Purpose: Multi-signature approval workflow
# Note: Signature is added to the envelope file
# Exit: 1 if signing fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Commit Configuration Update Transaction
# ----------------------------------------------------------------------------
# Description: Submits signed config update to orderer for commitment
# Parameters:
#   $1 - Path to signed update transaction envelope
# Purpose: Finalizes configuration change on the channel
# Process:
#   1. Submit transaction to orderer
#   2. Orderer validates signatures
#   3. Orderer commits update to channel
#   4. Clean up temporary files
# Exit: 1 if commit fails
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Set Anchor Peer
# ----------------------------------------------------------------------------
# Description: Configures anchor peer for organization in channel
# Purpose: Enables cross-organization gossip and service discovery
# Process:
#   1. Fetch current channel configuration
#   2. Add/update AnchorPeers section for organization
#   3. Create and commit configuration update
# Note: Anchor peer info (host/port) from organization configuration
# Exit: 1 if anchor peer configuration fails
# ----------------------------------------------------------------------------
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