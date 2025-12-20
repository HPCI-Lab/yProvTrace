#!/bin/bash

# ============================================================================
# yProvTrace: Organization Leave/Cleanup Script
# ============================================================================
# Description:
#   Performs local cleanup after an organization has been removed from
#   the channel. This script removes the organization's public identity
#   and optionally deletes private crypto material.
#
# Requirements:
#   - Organization must have been removed from channel first
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must be set to leaving organization
#
# Cleanup Modes:
#   Normal: Removes public identity only
#   Hard:   Removes both public identity and private crypto material
#
# Arguments:
#   --hard : Optional flag to delete private crypto material
#
# Warning:
#   Using --hard permanently deletes all certificates and keys
#
# Exit Codes:
#   1 - Identity verification or removal failed
# ============================================================================

source crypto-utils.sh
source ids-utils.sh

# Verify the identity of the caller
verify_identity

# Remove the organization's public identity from the network
remove_identity

# Optionally remove private crypto material if --hard flag is provided
[[ "$1" == "--hard" ]] && delete_crypto

