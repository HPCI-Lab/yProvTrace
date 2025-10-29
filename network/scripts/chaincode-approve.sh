#!/bin/bash

. ids-utils.sh
. cc-utils.sh

ORG_DOMAIN=$1

# Check if the organization domain is provided
if [ -z "$ORG_DOMAIN" ]; then
    echo "Usage: $0 <org-domain>"
    exit 1
fi

# Verify the identity of the caller
verify_identity "$ORG_DOMAIN"

# Set the default orderer and peer
set_orderer ${DEFAULT_ORD}                
set_peer ${ORG_DOMAIN} ${DEFAULT_PEER_ID}

# Calculate the package ID for the chaincode (INFO only)
PACKAGE_ID=$(calculate_package_id)

if [ -z "$PACKAGE_ID" ]; then
    echo "Failed to calculate package ID."
    exit 1
fi

# Resolve the sequence number for the chaincode
resolveSequence

# Approve the chaincode for the organization
approve_chaincode ${PACKAGE_ID} 