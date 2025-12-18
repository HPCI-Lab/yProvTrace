#!/bin/bash

export ORG_CONFIG_FILE="None"

source network-utils.sh

if [ ! -d "${NETWORK_CHN_PATH}" ]; then
    mkdir -p ${NETWORK_CHN_PATH}
fi

# Generate the genesis block
# NOTE: Genesis block is created by the admin organization (Org1) and then shared with all other organizations.
generate_genesis