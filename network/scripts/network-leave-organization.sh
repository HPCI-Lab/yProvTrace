#!/bin/bash

. crypto-utils.sh
. ids-utils.sh

ORG_DOMAIN=$1
[[ "$2" == "--hard" ]] && HARD=true || HARD=false

# Check if the domain is set
if [ -z "${ORG_DOMAIN}" ]; then
    echo "Usage: $0 <org_domain>"
    exit 1
fi

# Verify the identity of the caller
verify_identity ${ORG_DOMAIN}

# Remove the public identity of the organization
remove_identity ${ORG_DOMAIN}

# Remove the organization crypto [Optional]
[[ "$HARD" == true ]] && delete_crypto ${ORG_DOMAIN}

