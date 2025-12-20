#!/bin/bash

# ============================================================================
# yProvTrace: Channel Update Commit Script
# ============================================================================
# Description:
#   Commits a signed channel configuration update to the network. This
#   finalizes the configuration change after sufficient organizations
#   have approved it.
#
# Use Cases:
#   - Committing new organization additions
#   - Committing organization removals
#   - Committing channel policy updates
#
# Requirements:
#   - Organization identity must be valid
#   - Update transaction must be signed by required organizations
#   - ORG_CONFIG_FILE must be set
#
# Arguments:
#   $1 - Path to signed update transaction envelope file (.pb)
#
# Process:
#   1. Verify organization identity
#   2. Submit signed transaction to orderer
#   3. Orderer validates signatures and commits update
#
# Note: Only one organization needs to submit (others approve only)
#
# Exit Codes:
#   1 - Transaction file missing or commit failed
# ============================================================================

source network-utils.sh
source ids-utils.sh

UPDATE_TRANSACTION_FILE=$1

# Check if the update transaction file is provided
if [ -z "${UPDATE_TRANSACTION_FILE}" ]; then
    log_error "Update transaction file argument is missing"
    exit 1
fi

# Check if the update transaction file exists
if [ ! -f "${UPDATE_TRANSACTION_FILE}" ]; then
    log_error "Update transaction file not found: ${UPDATE_TRANSACTION_FILE}"
    exit 1
fi

# Verify the identity of the caller
verify_identity

# Submit the configuration update to the orderer
commit_update_transaction ${UPDATE_TRANSACTION_FILE}