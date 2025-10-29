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
verify_identity ${ORG_DOMAIN}

# Resolve the sequence number for the chaincode
resolveSequence

# Install the chaincode
install_chaincode ${ORG_DOMAIN}