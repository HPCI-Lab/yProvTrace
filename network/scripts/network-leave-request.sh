#!/bin/bash

# ============================================================================
# yProvTrace: Organization Leave Request Script
# ============================================================================
# Description:
#   Creates a channel configuration update to remove an organization from
#   the channel. This is the first step in the organization removal workflow.
#
# Workflow:
#   1. Fetch current channel configuration
#   2. Remove organization from configuration
#   3. Create signed update transaction
#
# Requirements:
#   - Requesting organization must have channel access
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must be set
#
# Arguments:
#   $1 - Path to organization's configtx.yaml (to identify org name)
#
# Output:
#   <orgname>_update_in_envelope.pb - Signed update transaction
#
# Next Steps:
#   1. All required organizations approve: network-approve-update.sh
#   2. One organization commits: network-commit-update.sh
#   3. Leaving org cleans up: network-leave-organization.sh
#
# Exit Codes:
#   1 - Configuration file missing or update creation failed
# ============================================================================

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

# Verify the requesting organization's identity
verify_identity

# Fetch the current channel configuration
fetch_channel_config

# Extract the organization name from the configtx file
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Remove the organization from the channel configuration
jq --arg org_name "${ORG_NAME}" 'del(.channel_group.groups.Application.groups[($org_name)])' ${CURRENT} > ${MODIFIED}

# Create the configuration update transaction
create_update_transaction ${ORG_NAME}