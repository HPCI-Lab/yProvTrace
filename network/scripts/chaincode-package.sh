#!/bin/bash

# ============================================================================
# yProvTrace: Chaincode Packaging Script
# ============================================================================
# Description:
#   Packages chaincode source code into a deployable .tar.gz archive for
#   installation on peers. This script validates all required parameters
#   and prepares the chaincode for lifecycle operations.
#
# Required Environment Variables:
#   - CHAINCODE_NAME       : Name of the chaincode
#   - CHAINCODE_SRC_PATH   : Path to chaincode source directory
#   - CHAINCODE_LANGUAGE   : Programming language (javascript/typescript)
#   - CHAINCODE_VERSION    : Version identifier
#
# Supported Languages:
#   - JavaScript (runtime: node)
#   - TypeScript (runtime: node)
#
# Output:
#   Creates .tar.gz package in NETWORK_PKG_PATH directory
# ============================================================================

export ORG_CONFIG_FILE="NONE"

source common.sh

# Validate that the chaincode name is provided

if [ -z "$CHAINCODE_NAME" ]; then
    log_error "No chaincode name was provided"
    exit 1

# Validate that the chaincode source path is provided
# User has not provided a path
elif [ -z "$CHAINCODE_SRC_PATH" ]; then
    log_error "No chaincode path was provided"
    exit 1

# Validate that the chaincode language is provided
elif [ -z "$CHAINCODE_LANGUAGE" ]; then
    log_error "No chaincode language was provided"
    exit 1

# Validate that the chaincode version is provided
elif [ -z "$CHAINCODE_VERSION" ]; then
    log_error "No chaincode version was provided"
    exit 1

# Make sure that the src path to the chaincode exists
elif [ ! -d "$CHAINCODE_SRC_PATH" ]; then
    log_error "Path to chaincode does not exist. Please provide a different path."
    exit 1
fi

# Convert language to lowercase for consistency
CHAINCODE_LANGUAGE=$(echo "$CHAINCODE_LANGUAGE" | tr [:upper:] [:lower:])

# Map chaincode language to Fabric runtime language
if [[ "$CHAINCODE_LANGUAGE" == "javascript" ]]; then
    CHAINCODE_RUNTIME_LANGUAGE="node"
else
    log_error "${CHAINCODE_LANGUAGE} is not supported by this script. Supported chaincode languages are: javascript."
    exit 1
fi

# Create package directory if it doesn't exist
if [ ! -d "$NETWORK_PKG_PATH" ]; then
    mkdir -p ${NETWORK_PKG_PATH}
fi

# Log chaincode configuration details
log_info "Chaincode Name: ${CHAINCODE_NAME}"
log_info "Chaincode Version: ${CHAINCODE_VERSION}"
log_info "Chaincode Source Path: ${CHAINCODE_SRC_PATH}"
log_info "Chaincode Language: ${CHAINCODE_LANGUAGE} (Runtime: ${CHAINCODE_RUNTIME_LANGUAGE})"

# Create the chaincode package using peer lifecycle
CHAINCODE_PKG_PATH=$(get_chaincode_package)
peer lifecycle chaincode package ${CHAINCODE_PKG_PATH} --path ${CHAINCODE_SRC_PATH} --lang ${CHAINCODE_RUNTIME_LANGUAGE} --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}

log_success "Chaincode packaged successfully at ${CHAINCODE_PKG_PATH}"