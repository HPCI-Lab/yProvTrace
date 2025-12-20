#!/bin/bash

# ============================================================================
# yProvTrace: Channel Update Approval Script
# ============================================================================
# Description:
#   Signs a channel configuration update transaction on behalf of the
#   current organization. Multiple organizations must approve updates
#   before they can be committed to the channel.
#
# Use Cases:
#   - Approving new organization join requests
#   - Approving organization leave requests
#   - Approving channel policy changes
#
# Requirements:
#   - Organization identity must be valid
#   - Update transaction file must exist
#   - ORG_CONFIG_FILE must be set
#
# Arguments:
#   $1 - Path to update transaction envelope file (.pb)
#
# Process:
#   1. Verify organization identity
#   2. Sign the update transaction with org's admin key
#
# Exit Codes:
#   1 - Transaction file missing or identity verification failed
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

# Sign the configuration update transaction
sign_update_transaction ${UPDATE_TRANSACTION_FILE}