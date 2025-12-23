#!/bin/bash

# ============================================================================
# yProvTrace: Requirements Installation Script
# ============================================================================
# Description:
#   Installs and configures all dependencies required for running the
#   yProvTrace network, including Hyperledger Fabric binaries and system
#   utilities.
#
# Installed Components:
#   1. Hyperledger Fabric binaries (peer, orderer, configtxgen, etc.)
#   2. System utilities (jq, yq, fzf)
#   3. Chaincode runtime validation (Node.js for JavaScript)
#
# Requirements:
#   - Docker must be installed
#   - Internet connection for downloads
#   - sudo privileges for apt package installation
#
# Fabric Binaries:
#   Downloaded from GitHub releases based on FABRIC_VERSION
#   Installed to: NETWORK_BIN_PATH (../bin)
#
# Note: ORG_CONFIG_FILE set to "NONE" to skip org selection
# ============================================================================

export ORG_CONFIG_FILE="NONE"

source common.sh

# ----------------------------------------------------------------------------
# Download Helper Function
# ----------------------------------------------------------------------------
# Description: Downloads and extracts Fabric binaries from GitHub
# Parameters:
#   $1 - Binary file name (unused, kept for compatibility)
#   $2 - Download URL
# Returns: 22 if download fails
# ----------------------------------------------------------------------------
download() {
    local BINARY_FILE=$1
    local URL=$2
    log_info "===> Downloading: " "${URL}"
    curl -L --retry 5 --retry-delay 3 "${URL}" | tar xz -C "../" bin  || rc=$?
    if [ -n "$rc" ]; then
        log_error "==> There was an error downloading the binary file."
        return 22
    else
        log_info "==> Done."
    fi
}

# ----------------------------------------------------------------------------
# Pull Fabric Binaries
# ----------------------------------------------------------------------------
# Description: Downloads platform-specific Fabric binaries
# Purpose: Retrieves peer, orderer, configtxgen, cryptogen, etc.
# Version: Uses FABRIC_VERSION from network configuration
# Exit: If binaries unavailable for the specified version
# ----------------------------------------------------------------------------
pull_binaries() {
    log_info "===> Downloading version ${FABRIC_VERSION} platform specific fabric binaries"
    download "${BINARY_FILE}" "https://github.com/hyperledger/fabric/releases/download/v${FABRIC_VERSION}/${BINARY_FILE}"
    if [ $? -eq 22 ]; then
        echo
        echo "------> ${FABRIC_VERSION} platform specific fabric binary is not available to download <----"
        echo
        exit
    fi
}

# ----------------------------------------------------------------------------
# Validation: Docker Installation
# ----------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker to proceed."
    exit 1
fi

# ----------------------------------------------------------------------------
# Validation: Chaincode Runtime
# ----------------------------------------------------------------------------
if [ "$CHAINCODE_LANGUAGE" = "javascript" ] || [ "$CHAINCODE_LANGUAGE" = "typescript" ]; then
    if ! command -v node &> /dev/null; then
        log_error "CHAINCODE_LANGUAGE is set to JavaScript/TypeScript, but Node.js is not installed. Please install Node.js to run the chaincode."
        exit 1
    fi
else
    log_error "Unsupported CHAINCODE_LANGUAGE: ${CHAINCODE_LANGUAGE}. Currently, only 'javascript' and 'typescript' are supported."
    exit 1  
fi

# ----------------------------------------------------------------------------
# Install System Utilities
# ----------------------------------------------------------------------------
sudo apt-get update
sudo apt-get install -y jq yq fzf

# ----------------------------------------------------------------------------
# Install Hyperledger Fabric Binaries
# ----------------------------------------------------------------------------
if [ ! -d "${NETWORK_BIN_PATH}" ]; then
    log_info "Hyperledger Fabric binaries not found. Installing requirements..."
    OS=$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')
    ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
    PLATFORM=${OS}-${ARCH}
    BINARY_FILE=hyperledger-fabric-${PLATFORM}-${FABRIC_VERSION}.tar.gz
    pull_binaries
else
    log_info "Hyperledger Fabric binaries found at: ${NETWORK_BIN_PATH}. Skipping installation."
fi
