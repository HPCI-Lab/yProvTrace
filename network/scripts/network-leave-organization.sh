#!/bin/bash

source crypto-utils.sh
source ids-utils.sh

# Verify the identity of the caller
verify_identity

# Remove the public identity of the organization
remove_identity

# Remove the organization crypto [Optional]
[[ "$1" == "--hard" ]] && delete_crypto

