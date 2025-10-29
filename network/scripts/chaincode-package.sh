#!/bin/bash

. set-env.sh

#User has not provided a name
if [ -z "$CC_NAME" ]; then
    echo "Error: No chaincode name was provided."
    exit 1

# User has not provided a path
elif [ -z "$CC_SRC_PATH" ]; then
    echo "Error: No chaincode path was provided."
    exit 1

# User has not provided a language
elif [ -z "$CC_SRC_LANG" ]; then
    echo "Error: No chaincode language was provided."
    exit 1

# User has not provided a version
elif [ -z "$CC_VERSION" ]; then
    echo "Error: No chaincode version was provided."
    exit 1

# Make sure that the src path to the chaincode exists
elif [ ! -d "$CC_SRC_PATH" ]; then
    echo "Error: Path to chaincode does not exist. Please provide a different path."
    exit 1
fi

CC_SRC_LANG=$(echo "$CC_SRC_LANG" | tr [:upper:] [:lower:])
if [ "$CC_SRC_LANG" = "go" ]; then
    CC_RUNTIME_LANG="golang"
elif [ "$CC_SRC_LANG" = "javascript" ] || [ "$CC_SRC_LANG" = "typescript" ]; then
    CC_RUNTIME_LANG="node"
else
    echo "Error: The chaincode language ${CC_SRC_LANG} is not supported by this script. Supported chaincode languages are: go, javascript, typescript."
    exit 1
fi

if [ ! -d "$NETWORK_PKG_PATH" ]; then
    mkdir -p ${NETWORK_PKG_PATH}
fi

echo "Chaincode name: ${CC_NAME}"
echo "Chaincode path: ${CC_SRC_PATH}"
echo "Chaincode language: ${CC_SRC_LANG} (${CC_RUNTIME_LANG})"
echo "Chaincode version: ${CC_VERSION}"

peer lifecycle chaincode package ${CC_PKG_PATH} --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANG} --label ${CC_NAME}_${CC_VERSION}
echo "Chaincode packaged successfully at ${CC_PKG_PATH}"