#!/bin/bash

. ../network.config

download() {
    local BINARY_FILE=$1
    local URL=$2
    echo "===> Downloading: " "${URL}"
    curl -L --retry 5 --retry-delay 3 "${URL}" | tar xz -C "../" bin  || rc=$?
    if [ -n "$rc" ]; then
        echo "==> There was an error downloading the binary file."
        return 22
    else
        echo "==> Done."
    fi
}

pull_binaries() {
    echo "===> Downloading version ${FABRIC_VERSION} platform specific fabric binaries"
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
    # TODO: should we install docker here for the user?
    echo "Docker is not installed. Please install Docker to run the network."
    exit 1
else
    echo "Docker is installed at: $(which docker)"
fi

# Check CC_SRC_LANG and tell user to install the required language runtime
# TODO: should we install the runtime language here for the user?
if [ "$CC_SRC_LANG" = "go" ]; then
    if ! command -v go &> /dev/null; then
        echo "CC_SRC_LANG is set to Go, but Go is not installed. Please install Go to run the chaincode."
        exit 1
    else
        echo "CC_SRC_LANG is set to Go. Go is installed at: $(which go)"
    fi
elif [ "$CC_SRC_LANG" = "javascript" ] || [ "$CC_SRC_LANG" = "typescript" ]; then
    if ! command -v node &> /dev/null; then
        echo "CC_SRC_LANG is set to JavaScript/TypeScript, but Node.js is not installed. Please install Node.js to run the chaincode."
        exit 1
    else
        echo "CC_SRC_LANG is set to JavaScript/TypeScript. Node.js is installed at: $(which node)"
    fi
fi

# Update and install required packages
sudo apt-get update
sudo apt-get install -y jq yq

# Install the Hyperledger Fabric binaries if they are not already installed
if [ ! -d "${NETWORK_BIN_PATH}" ]; then
    echo "Hyperledger Fabric binaries not found. Installing requirements..."
    OS=$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')
    ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
    PLATFORM=${OS}-${ARCH}
    BINARY_FILE=hyperledger-fabric-${PLATFORM}-${FABRIC_VERSION}.tar.gz
    pull_binaries
else
    echo "Hyperledger Fabric binaries found at: ${NETWORK_BIN_PATH}. Skipping installation."
fi
