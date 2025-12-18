#!/bin/bash

source ids-utils.sh
source cc-utils.sh


# Verify the identity of the caller
verify_identity 

# Resolve the sequence number for the chaincode
resolveSequence

# Approve the chaincode for the organization
approve_chaincode