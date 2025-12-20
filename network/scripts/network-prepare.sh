#!/bin/bash

# ============================================================================
# yProvTrace: Network Preparation Script
# ============================================================================
# Description:
#   Comprehensive setup script that prepares an organization for network
#   participation. This script handles all cryptographic material generation
#   and identity distribution.
#
# Operations Performed:
#   1. Generate crypto material (certificates, keys, MSP structure)
#   2. Share public MSP/TLS certificates with network
#   3. Generate endpoint metadata (service discovery)
#   4. Create connection profile (CCP) for client applications
#
# Requirements:
#   - Crypto configuration file must exist (YAML)
#   - ORG_CONFIG_FILE must be set
#
# Arguments:
#   $1 - Path to cryptogen configuration file (YAML)
#
# Output Directories:
#   - NETWORK_ORG_PATH : Private crypto material (local only)
#   - NETWORK_IDS_PATH : Public identities (shared with network)
#
# Use Cases:
#   - Initial setup for founding organizations
#   - Preparing new organizations to join the network
#
# Exit Codes:
#   1 - Configuration file missing or crypto generation failed
# ============================================================================

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

# Create required directories if they don't exist
if [ ! -d "${NETWORK_ORG_PATH}" ]; then
    mkdir -p ${NETWORK_ORG_PATH}
fi

if [ ! -d "${NETWORK_IDS_PATH}" ]; then
    mkdir -p ${NETWORK_IDS_PATH}
fi

# Step 1: Generate cryptographic material
generate_crypto ${CRYPTO_CONFIG_FILE}

# Step 2: Share public certificates with the network
copy_msp_folder

# Step 3: Generate service endpoint metadata
generate_endpoints

# Step 4: Create connection profile for client applications
generate_ccp ${CRYPTO_CONFIG_FILE}