#!/bin/bash

. network-utils.sh
. ids-utils.sh

ORG_CONFIGTX_FILE=$1
ORG_DOMAIN=$2

# Check if the organization domain is set
if [ -z "${ORG_CONFIGTX_FILE}" ] || [ -z "${ORG_DOMAIN}" ]; then
    echo "Usage: $0 <org_configtx_file> <org_domain>"
    exit 1
fi

# Check if the file exists
if [ ! -f "${ORG_CONFIGTX_FILE}" ]; then
    echo "Configuration file ${ORG_CONFIGTX_FILE} does not exist."
    exit 1
fi

# verify the identity of the caller
verify_identity ${ORG_DOMAIN}

# Fetch the latest channel configuration block and decode it to JSON
fetch_channel_config ${ORG_DOMAIN}

# Extract information from the organization definition
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Remove the organization from the channel configuration
jq --arg org_name "${ORG_NAME}" 'del(.channel_group.groups.Application.groups[($org_name)])' ${CURRENT} > ${MODIFIED}

# Create the update transaction
create_update_transaction ${ORG_NAME}