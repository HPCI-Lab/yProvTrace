#!/bin/bash

. ../network.config

export PATH=${PATH}:${NETWORK_BIN_PATH}
export FABRIC_CFG_PATH=${NETWORK_CFG_PATH}
export COMPOSE_BAKE=true
export FABRIC_VERSION

# General Files
GENESIS_BLOCK=${NETWORK_CHN_PATH}/genesis.block
CC_PKG_PATH=${NETWORK_PKG_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz

set_orderer() {
    local orderer_hostname=$1
    local ord_domain=$(echo "$orderer_hostname" | cut -d'.' -f2-)
    local endpoints_file="${NETWORK_IDS_PATH}/ordererOrganizations/${ord_domain}/endpoints.json"
    
    if [ ! -f "${endpoints_file}" ]; then
        echo "Error: Endpoints file ${endpoints_file} does not exist."
        exit 1
    fi

    local orderer=$(jq -r "map(select(.hostname == \"$orderer_hostname\")) | .[0]" "$endpoints_file")

    if [ -z "$orderer" ]; then
        echo "Error: Orderer with hostname '$2' not found in $1."
        exit 1
    fi

    export ORDERER_DOMAIN=$(echo "$orderer" | jq -r '.domain')
    export ORDERER_HOSTNAME=$(echo "$orderer" | jq -r '.hostname')
    export ORDERER_ADDRESS=$(echo "$orderer" | jq -r '.address')
    export ORDERER_ADMIN_ADDRESS=$(echo "$orderer" | jq -r '.adminAddress')

    # NOTE: these can be get from both organizations and identities folders, since they are public
    export ORDERER_TLS_CA="${NETWORK_IDS_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/msp/tlscacerts/tlsca.${ORDERER_DOMAIN}-cert.pem"
    export ORDERER_TLS_SIGN_CERT="${NETWORK_IDS_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/tls/server.crt"

    # NOTE: this is private and should not be in the shared identity folder
    export ORDERER_TLS_PRIVATE_KEY="${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_HOSTNAME}/tls/server.key"

    echo "Setting environment for ${ORDERER_HOSTNAME}:"
    echo "  Address: ${ORDERER_ADDRESS}"
    echo "  Admin Address: ${ORDERER_ADMIN_ADDRESS}"
    echo "  TLS CA: ${ORDERER_TLS_CA}"
    echo "  TLS Sign Cert: ${ORDERER_TLS_SIGN_CERT}"
    echo "  TLS Private Key: ${ORDERER_TLS_PRIVATE_KEY}"
}

set_peer() {
    local org_domain=$1
    local peer_id=$2
    local endpoints_file="${NETWORK_IDS_PATH}/peerOrganizations/${org_domain}/endpoints.json"

    if [ ! -f "${endpoints_file}" ]; then
        echo "Error: Endpoints file ${endpoints_file} does not exist."
        exit 1
    fi

    local peer=$(jq -r --arg id "$peer_id" '.[$id]' "$endpoints_file")

    if [ -z "$peer" ]; then
        echo "Error: Peer with ID '$peer_id' not found in $endpoints_file."
        exit 1
    fi

    export PEER_HOSTNAME=$(echo "$peer" | jq -r '.hostname')
    export PEER_DOMAIN=$(echo "$PEER_HOSTNAME" | cut -d'.' -f2-)
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=$(echo "$peer" | jq -r '.localMspId')
    export CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.address')
    
    # NOTE: this can be get from both organizations and identities folders, since it is public
    export CORE_PEER_TLS_ROOTCERT_FILE="${NETWORK_IDS_PATH}/peerOrganizations/${PEER_DOMAIN}/msp/tlscacerts/tlsca.${PEER_DOMAIN}-cert.pem"
    
    # NOTE: this is private and should not be in the shared identity folder
    export CORE_PEER_MSPCONFIGPATH="${NETWORK_ORG_PATH}/peerOrganizations/${PEER_DOMAIN}/users/Admin@${PEER_DOMAIN}/msp"

    echo "Setting environment for ${PEER_HOSTNAME} (ID: $2):"
    echo "  Address: ${CORE_PEER_ADDRESS}"
    echo "  Local MSP ID: ${CORE_PEER_LOCALMSPID}"
    echo "  TLS Root Cert: ${CORE_PEER_TLS_ROOTCERT_FILE}"
    echo "  MSP Config Path: ${CORE_PEER_MSPCONFIGPATH}"
    echo "  TLS Enabled: ${CORE_PEER_TLS_ENABLED}"
}