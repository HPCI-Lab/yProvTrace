#!/bin/bash

source network-utils.sh
source ids-utils.sh

ORG_CONFIGTX_FILE=$1

# Generate the organization definition file
DEFINITION_FILE=$(generate_definition ${ORG_CONFIGTX_FILE})

# verify the identity of the caller
verify_identity

# Fetch the latest channel configuration block and decode it to JSON
fetch_channel_config

# Extract information from the organization definition
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Add the new organization to the config
jq -s --arg org_msp "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_msp):.[1]}}}}}' ${CURRENT} ${DEFINITION_FILE} > ${MODIFIED}

# Create the update transaction
create_update_transaction ${ORG_NAME}

# ? Remove organization definition file after use
rm -f ${DEFINITION_FILE}