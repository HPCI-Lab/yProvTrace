#!/bin/bash

source ids-utils.sh

# ============================================================================
# Chaincode Utility Functions
# ============================================================================

calculate_package_id() {
    local CC_PKG_PATH=$(get_chaincode_package)
    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PKG_PATH})
    echo "${PACKAGE_ID}"
}

resolveSequence() {
    COMMITTED_CC_SEQUENCE=$(peer lifecycle chaincode querycommitted --channelID $NETWORK_CHN_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    
    if [ -z "$COMMITTED_CC_SEQUENCE" ]; then
        export CHAINCODE_SEQUENCE=1
    else
        APPROVED_CC_SEQUENCE=$(peer lifecycle chaincode queryapproved --channelID $NETWORK_CHN_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")

        if [ -z "$APPROVED_CC_SEQUENCE" ] || [ "$COMMITTED_CC_SEQUENCE" == "$APPROVED_CC_SEQUENCE" ]; then
            export CHAINCODE_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
        else
            export CHAINCODE_SEQUENCE=$APPROVED_CC_SEQUENCE
        fi
    fi

    log_info "Resolved chaincode sequence number: ${CHAINCODE_SEQUENCE}"
}

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

invoke_chaincode() {

    # TODO: add params
    # TODO: single function for all invokations or separate? Maybe contract-utils.sh ?

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
}

query_chaincode() {

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
}