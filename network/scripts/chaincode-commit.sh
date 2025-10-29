#!/bin/bash

. cc-utils.sh

ORG_DOMAIN=$1

# Check if the organization domain is provided
if [ -z "$ORG_DOMAIN" ]; then
    echo "Usage: $0 <org_domain>"
    exit 1
fi

# Verify the identity of the caller
verify_identity ${ORG_DOMAIN}

# Set the default orderer and peer
set_orderer ${DEFAULT_ORD}
set_peer ${ORG_DOMAIN} ${DEFAULT_PEER_ID}

# Resolve the sequence number for the chaincode
resolveSequence

# Check the commit readiness of the chaincode
check_commit_readiness

# Commit the chaincode
commit_chaincode