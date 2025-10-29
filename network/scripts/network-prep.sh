#!/bin/bash

. crypto-utils.sh
. ids-utils.sh

CRYPTO_CONFIG_FILE=$1
DOCKER_COMPOSE_FILE=$2

# Check if the crypto config file is provided
if [ -z "$CRYPTO_CONFIG_FILE" ] || [ -z "$DOCKER_COMPOSE_FILE" ]; then
    echo "Usage: $0 <crypto-config-file> <docker-compose-file>"
    exit 1
fi

# Check if the crypto config file exists
if [ ! -f "$CRYPTO_CONFIG_FILE" ]; then
    echo "Crypto config file not found: $CRYPTO_CONFIG_FILE"
    exit 1
fi

# Check if the docker compose file exists
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Docker compose file not found: $DOCKER_COMPOSE_FILE"
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
ORG_DIR=$(copy_msp_folder ${CRYPTO_CONFIG_FILE})

# Generate the endpoints definition
generate_endpoints ${ORG_DIR} ${DOCKER_COMPOSE_FILE}

# Generate the common connection profile
generate_ccp ${CRYPTO_CONFIG_FILE}

echo "Network identity generated successfully at ${ORG_DIR}"