#!/bin/bash

# ============================================================================
# yProvTrace: Network Genesis Block Generation Script
# ============================================================================
# Description:
#   Creates the genesis block for the application channel. The genesis
#   block contains the initial channel configuration and is used by all
#   members to join the channel.
#
# Responsibility:
#   Typically run by the admin/lead organization to bootstrap the network
#
# Requirements:
#   - All founding members must have generated crypto material
#   - Channel configuration (configtx.yaml) must be present
#   - NETWORK_CHN_PATH directory must exist
#
# Output:
#   genesis.block - Channel genesis block in NETWORK_CHN_PATH
#
# Note: ORG_CONFIG_FILE set to "NONE" as genesis creation is network-wide
#
# Exit Codes:
#   1 - Genesis block creation failed
# ============================================================================

export ORG_CONFIG_FILE="NONE"

source network-utils.sh

# Create channel artifacts directory if it doesn't exist
if [ ! -d "${NETWORK_CHN_PATH}" ]; then
    mkdir -p ${NETWORK_CHN_PATH}
fi

# Generate the channel genesis block using configtxgen
generate_genesis