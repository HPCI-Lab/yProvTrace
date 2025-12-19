#!/bin/bash

source crypto-utils.sh
source ids-utils.sh

CRYPTO_CONFIG_FILE=$1

# Check if the crypto config file is provided
if [ -z "$CRYPTO_CONFIG_FILE" ]; then
    log_error "Crypto config file not specified."
    exit 1
fi

# Check if the crypto config file exists
if [ ! -f "$CRYPTO_CONFIG_FILE" ]; then
    log_error "Crypto config file '$CRYPTO_CONFIG_FILE' does not exist."
    exit 1
fi

# Create the necessary directories
if [ ! -d "${NETWORK_ORG_PATH}" ]; then
    mkdir -p ${NETWORK_ORG_PATH}
fi

if [ ! -d "${NETWORK_IDS_PATH}" ]; then
    mkdir -p ${NETWORK_IDS_PATH}
fi

# Generate the crypto material
generate_crypto ${CRYPTO_CONFIG_FILE}

# Copy the CA and TLS certificates
copy_msp_folder

# Generate the endpoints definition
generate_endpoints

# Generate the common connection profile
generate_ccp ${CRYPTO_CONFIG_FILE}

log_success "Network preparation completed for organization: ${ORG_DOMAIN}"