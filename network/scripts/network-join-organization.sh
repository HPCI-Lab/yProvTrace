#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORG_DOMAIN=$1

# Check if organization domain is provided
if [ -z "$ORG_DOMAIN" ]; then
    echo "Usage: $0 <organization_domain>"
    exit 1
fi

# Check if the organization exists in the identities folder
if [ ! -d "${NETWORK_IDS_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
    echo "Error: Organization '${ORG_DOMAIN}' does not exist in the identities folder."
    exit 1
fi

# Verify the identity of the caller
verify_identity "$ORG_DOMAIN"

# Join the organization to the network
join_organization "$ORG_DOMAIN"