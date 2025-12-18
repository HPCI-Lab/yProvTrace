#!/bin/bash

source cc-utils.sh

# Verify the identity of the caller
verify_identity

# Resolve the sequence number for the chaincode
resolveSequence

# Check the commit readiness of the chaincode
check_commit_readiness

# Commit the chaincode
commit_chaincode