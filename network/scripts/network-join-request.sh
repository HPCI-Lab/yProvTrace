#!/bin/bash

# ============================================================================
# yProvTrace: Organization Join Request Script
# ============================================================================
# Description:
#   Creates a channel configuration update to add a new organization to
#   an existing channel. This is the first step in the dynamic membership
#   workflow.
#
# Workflow:
#   1. Generate organization definition from configtx file
#   2. Fetch current channel configuration
#   3. Add new organization to configuration
#   4. Create signed update transaction
#
# Requirements:
#   - New organization must have crypto material prepared
#   - Requesting organization must have channel access
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must be set to existing member
#
# Arguments:
#   $1 - Path to new organization's configtx.yaml
#
# Output:
#   <orgname>_update_in_envelope.pb - Signed update transaction
#
# Next Steps:
#   1. All required organizations approve: network-approve-update.sh
#   2. One organization commits: network-commit-update.sh
#
# Exit Codes:
#   1 - Configuration file missing or update creation failed
# ============================================================================

source network-utils.sh
source ids-utils.sh

ORG_CONFIGTX_FILE=$1

# Generate the organization definition from configtx
DEFINITION_FILE=$(generate_definition ${ORG_CONFIGTX_FILE})

# Verify the requesting organization's identity
verify_identity

# Fetch the latest channel configuration
fetch_channel_config

# Extract the new organization's name from configtx
ORG_NAME=$(yq -r '.Organizations[0].Name' ${ORG_CONFIGTX_FILE})

# Merge new organization into channel configuration
jq -s --arg org_msp "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_msp):.[1]}}}}}' ${CURRENT} ${DEFINITION_FILE} > ${MODIFIED}

# Create the configuration update transaction
create_update_transaction ${ORG_NAME}

# Clean up temporary definition file
# ? Remove organization definition file after use
rm -f ${DEFINITION_FILE}