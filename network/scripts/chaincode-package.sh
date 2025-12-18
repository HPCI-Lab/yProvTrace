#!/bin/bash

source common.sh

#User has not provided a name
if [ -z "$CHAINCODE_NAME" ]; then
    log_error "No chaincode name was provided"
    exit 1

# User has not provided a path
elif [ -z "$CHAINCODE_SRC_PATH" ]; then
    log_error "No chaincode path was provided"
    exit 1

# User has not provided a language
elif [ -z "$CHAINCODE_LANGUAGE" ]; then
    log_error "No chaincode language was provided"
    exit 1

# User has not provided a version
elif [ -z "$CHAINCODE_VERSION" ]; then
    log_error "No chaincode version was provided"
    exit 1

# Make sure that the src path to the chaincode exists
elif [ ! -d "$CHAINCODE_SRC_PATH" ]; then
    log_error "Path to chaincode does not exist. Please provide a different path."
    exit 1
fi

CHAINCODE_LANGUAGE=$(echo "$CHAINCODE_LANGUAGE" | tr [:upper:] [:lower:])

if [[ "$CHAINCODE_LANGUAGE" == "javascript" ]]; then
    CHAINCODE_RUNTIME_LANGUAGE="node"
else
    log_error "${CHAINCODE_LANGUAGE} is not supported by this script. Supported chaincode languages are: javascript."
    exit 1
fi

if [ ! -d "$NETWORK_PKG_PATH" ]; then
    mkdir -p ${NETWORK_PKG_PATH}
fi

log_info "Chaincode Name: ${CHAINCODE_NAME}"
log_info "Chaincode Version: ${CHAINCODE_VERSION}"
log_info "Chaincode Source Path: ${CHAINCODE_SRC_PATH}"
log_info "Chaincode Language: ${CHAINCODE_LANGUAGE} (Runtime: ${CHAINCODE_RUNTIME_LANGUAGE})"

CHAINCODE_PKG_PATH=$(get_chaincode_package)
peer lifecycle chaincode package ${CHAINCODE_PKG_PATH} --path ${CHAINCODE_SRC_PATH} --lang ${CHAINCODE_RUNTIME_LANGUAGE} --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}

log_success "Chaincode packaged successfully at ${CHAINCODE_PKG_PATH}"