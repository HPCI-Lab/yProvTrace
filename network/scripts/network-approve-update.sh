#!/bin/bash

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

# Sign the update transaction
sign_update_transaction ${UPDATE_TRANSACTION_FILE}