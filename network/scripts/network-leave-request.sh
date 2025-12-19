#!/bin/bash

source network-utils.sh
source ids-utils.sh

ORG_CONFIGTX_FILE=$1

# Check if the organization config file is passed
if [ -z "${ORG_CONFIGTX_FILE}" ]; then
    log_error "Organization config file not specified"
    exit 1
fi

# Check if the file exists
if [ ! -f "${ORG_CONFIGTX_FILE}" ]; then
    log_error "Configuration file ${ORG_CONFIGTX_FILE} does not exist"
    exit 1
fi

# verify the identity of the caller
verify_identity

# Fetch the latest channel configuration block and decode it to JSON
fetch_channel_config

# Extract information from the organization definition
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Remove the organization from the channel configuration
jq --arg org_name "${ORG_NAME}" 'del(.channel_group.groups.Application.groups[($org_name)])' ${CURRENT} > ${MODIFIED}

# Create the update transaction
create_update_transaction ${ORG_NAME}