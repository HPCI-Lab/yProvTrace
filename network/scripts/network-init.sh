#!/bin/bash

. network-utils.sh

# Force create the necessary directories (for emulation purposes)
rm -rf ${NETWORK_CHN_PATH}
mkdir -p ${NETWORK_CHN_PATH}

# Generate the genesis block
# NOTE: Genesis block is created by the admin organization (Org1) and then shared with all other organizations.
generate_genesis