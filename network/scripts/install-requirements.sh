#!/bin/bash

export ORG_CONFIG_FILE="NONE"

source common.sh

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

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker to proceed."
    exit 1
fi

# Check CC_SRC_LANG and tell user to install the required language runtime
if [ "$CHAINCODE_LANGUAGE" = "javascript" ] || [ "$CHAINCODE_LANGUAGE" = "typescript" ]; then
    if ! command -v node &> /dev/null; then
        log_error "CHAINCODE_LANGUAGE is set to JavaScript/TypeScript, but Node.js is not installed. Please install Node.js to run the chaincode."
        exit 1
    fi
else
    log_error "Unsupported CHAINCODE_LANGUAGE: ${CHAINCODE_LANGUAGE}. Currently, only 'javascript' and 'typescript' are supported."
    exit 1  
fi

# Update and install required packages
sudo apt-get update
sudo apt-get install -y jq yq fzf

# Install the Hyperledger Fabric binaries if they are not already installed
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
