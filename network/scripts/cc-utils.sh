#!/bin/bash

# ============================================================================
# yProvTrace: Chaincode Utility Functions
# ============================================================================
# Description:
#   This script provides utility functions for managing chaincode lifecycle
#   operations in Hyperledger Fabric, including package ID calculation,
#   sequence resolution, installation, approval, commitment, and testing.
#
# Functions:
#   - calculate_package_id()      : Compute the package ID for chaincode
#   - resolveSequence()           : Determine next sequence number for updates
#   - check_commit_readiness()    : Verify chaincode readiness for commit
#   - install_chaincode()         : Install chaincode on peer
#   - approve_chaincode()         : Approve chaincode for organization
#   - commit_chaincode()          : Commit chaincode definition to channel
#   - invoke_chaincode()          : Test chaincode invocation
#   - query_chaincode()           : Test chaincode query
# ============================================================================

source ids-utils.sh

# ----------------------------------------------------------------------------
# Calculate Package ID
# ----------------------------------------------------------------------------
# Description: Computes the package ID for a given chaincode package
# Returns: Package ID string (hash-based identifier)
# ----------------------------------------------------------------------------
calculate_package_id() {
    local CC_PKG_PATH=$(get_chaincode_package)
    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PKG_PATH})
    echo "${PACKAGE_ID}"
}

# ----------------------------------------------------------------------------
# Resolve Sequence Number
# ----------------------------------------------------------------------------
# Description: Determines the appropriate sequence number for chaincode updates
# Logic:
#   - If chaincode not committed: sequence = 1
#   - If committed but not approved: sequence = committed + 1
#   - If already approved: use approved sequence
# Exports: CHAINCODE_SEQUENCE (global variable)
# ----------------------------------------------------------------------------
resolveSequence() {
    set_peer_env

    COMMITTED_CC_SEQUENCE=$(peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CHAINCODE_NAME} 2>/dev/null | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    
    if [ -z "$COMMITTED_CC_SEQUENCE" ]; then
        export CHAINCODE_SEQUENCE=1
    else
        APPROVED_CC_SEQUENCE=$(peer lifecycle chaincode queryapproved --channelID $CHANNEL_NAME --name ${CHAINCODE_NAME} 2>/dev/null | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")

        if [ -z "$APPROVED_CC_SEQUENCE" ] || [ "$COMMITTED_CC_SEQUENCE" == "$APPROVED_CC_SEQUENCE" ]; then
            export CHAINCODE_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
        else
            export CHAINCODE_SEQUENCE=$APPROVED_CC_SEQUENCE
        fi
    fi

    log_info "Resolved chaincode sequence number: ${CHAINCODE_SEQUENCE}"
}

# ----------------------------------------------------------------------------
# Check Commit Readiness
# ----------------------------------------------------------------------------
# Description: Verifies if chaincode definition meets commit requirements
# Purpose: Ensures all required organizations have approved before commit
# Output: JSON showing approval status per organization
# Exit: 1 if readiness check fails
# ----------------------------------------------------------------------------
check_commit_readiness() {
    set_peer_env
    peer lifecycle chaincode checkcommitreadiness \
        --channelID ${CHANNEL_NAME} \
        --name ${CHAINCODE_NAME} \
        --version ${CHAINCODE_VERSION} \
        --sequence ${CHAINCODE_SEQUENCE} \
        --output json
    
    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' commit readiness check failed for organization ${ORG_DOMAIN}"
        exit 1
    fi

    log_success "Chaincode '${CHAINCODE_NAME}' commit readiness check succeeded for organization ${ORG_DOMAIN}"
}

# ----------------------------------------------------------------------------
# Install Chaincode
# ----------------------------------------------------------------------------
# Description: Installs chaincode package on the current peer
# Requirements: Chaincode must be packaged first
# Purpose: Deploys chaincode binary to peer for execution
# Exit: 1 if installation fails
# ----------------------------------------------------------------------------
install_chaincode() {

    set_peer_env

    local CC_PKG_PATH=$(get_chaincode_package)
    peer lifecycle chaincode install ${CC_PKG_PATH}
    
    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' installation failed on peer ${CORE_PEER_ADDRESS}"
        exit 1
    fi

    log_success "Chaincode '${CHAINCODE_NAME}' installed on peer ${CORE_PEER_ADDRESS}"
}

# ----------------------------------------------------------------------------
# Approve Chaincode
# ----------------------------------------------------------------------------
# Description: Approves chaincode definition for the organization
# Requirements: Chaincode must be installed on at least one peer
# Purpose: Organization-level endorsement of chaincode definition
# Note: All organizations must approve before commit
# Exit: 1 if approval fails
# ----------------------------------------------------------------------------
approve_chaincode() {
    set_peer_env

    local PACKAGE_ID=$(calculate_package_id)
    log_debug "Calculated package ID: ${PACKAGE_ID}"

    get_default_orderer

    peer lifecycle chaincode approveformyorg \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA} \
        --channelID ${CHANNEL_NAME} \
        --package-id ${PACKAGE_ID} \
        --name ${CHAINCODE_NAME} \
        --version ${CHAINCODE_VERSION} \
        --sequence ${CHAINCODE_SEQUENCE}
    
    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' approval failed for organization ${ORG_DOMAIN}"
        exit 1
    fi  

    log_success "Chaincode '${CHAINCODE_NAME}' approved for organization ${ORG_DOMAIN}"
}

# ----------------------------------------------------------------------------
# Commit Chaincode
# ----------------------------------------------------------------------------
# Description: Commits chaincode definition to the channel
# Requirements: Majority of organizations must have approved
# Purpose: Finalizes chaincode deployment across the channel
# Note: Collects TLS identities from all peer organizations
# Exit: 1 if commit fails
# ----------------------------------------------------------------------------
commit_chaincode() {
    
    local tls_identities=$(get_tls_identities)

    get_default_orderer

    peer lifecycle chaincode commit \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA} \
        --channelID ${CHANNEL_NAME} \
        --name ${CHAINCODE_NAME} \
        --version ${CHAINCODE_VERSION} \
        --sequence ${CHAINCODE_SEQUENCE} \
        ${tls_identities}
    
    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' commit failed on channel ${CHANNEL_NAME}"
        exit 1
    fi

    log_success "Chaincode '${CHAINCODE_NAME}' committed on channel ${CHANNEL_NAME}"
}

# ----------------------------------------------------------------------------
# Invoke Chaincode (Test Function)
# ----------------------------------------------------------------------------
# Description: Test function to invoke chaincode transaction
# Purpose: Creates a sample resource entry for testing
# Note: Generates hash using sha256sum (Linux) or shasum (macOS)
# Exit: 1 if commit fails
# ----------------------------------------------------------------------------
invoke_chaincode() {

    TIMESTAMP=$(date +%s%3N)
    PID="pid_test_${ORG_DOMAIN}"
    URI="https://example.com/resource/$PID"
    
    # Generate hash - use shasum on macOS, sha256sum on Linux
    if command -v sha256sum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | sha256sum | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback to a simple hash
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | od -An -tx1 | tr -d ' \n')
    fi
    
    # Construct the JSON payload properly
    JSON_PAYLOAD="{\"Function\":\"CreateResource\",\"Args\":[\"$PID\",\"$URI\",\"$HASH\",\"$TIMESTAMP\",\"[\\\"owner1\\\",\\\"owner2\\\"]\"]}"
    
    TLS_IDENTITIES=$(get_tls_identities)

    get_default_orderer
    set_peer_env 

    peer chaincode invoke \
        -o $ORDERER_ADDRESS \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --tls \
        --cafile $ORDERER_TLS_CA \
        ${TLS_IDENTITIES} \
        -c "$JSON_PAYLOAD"
    
    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' invocation failed on channel ${CHANNEL_NAME}"
        exit 1
    fi

    log_success "Chaincode '${CHAINCODE_NAME}' invoked successfully on channel ${CHANNEL_NAME}"
}

# ----------------------------------------------------------------------------
# Query Chaincode (Test Function)
# ----------------------------------------------------------------------------
# Description: Test function to query chaincode state
# Purpose: Reads a sample resource entry for verification
# Note: Queries the resource created by invoke_chaincode()
# Exit: 1 if commit fails
# ----------------------------------------------------------------------------
query_chaincode() {

    # Test function to query the chaincode

    PID="pid_test_${ORG_DOMAIN}"
    JSON_PAYLOAD="{\"Args\":[\"ReadResource\",\"$PID\"]}"
    
    get_default_orderer
    set_peer_env 

    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --tls \
        --cafile $ORDERER_TLS_CA \
        --peerAddresses "${CORE_PEER_ADDRESS}" \
        --tlsRootCertFiles "${CORE_PEER_TLS_ROOTCERT_FILE}" \
        -c "$JSON_PAYLOAD"

    if [ $? -ne 0 ]; then
        log_error "Chaincode '${CHAINCODE_NAME}' query failed on channel ${CHANNEL_NAME}"
        exit 1
    fi

    log_success "Chaincode '${CHAINCODE_NAME}' queried successfully on channel ${CHANNEL_NAME}"
}