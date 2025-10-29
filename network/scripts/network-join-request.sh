#!/bin/bash

. network-utils.sh
. ids-utils.sh

ORG_CONFIGTX_FILE=$1
ORG_DOMAIN=$2

# Generate the organization definition file
DEFINITION_FILE=$(generate_definition ${ORG_CONFIGTX_FILE})

# Check if the organization domain is set
if [ -z "${ORG_DOMAIN}" ]; then
    echo "Error: Organization domain is not specified."
    exit 1
fi

# verify the identity of the caller
verify_identity ${ORG_DOMAIN}

# Fetch the latest channel configuration block and decode it to JSON
fetch_channel_config ${ORG_DOMAIN}

# Extract information from the organization definition
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Add the new organization to the config
jq -s --arg org_msp "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_msp):.[1]}}}}}' ${CURRENT} ${DEFINITION_FILE} > ${MODIFIED}

# Create the update transaction
create_update_transaction ${ORG_NAME}

# TODO: Remove organization definition file after use?
rm -f ${DEFINITION_FILE}