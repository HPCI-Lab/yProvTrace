#!/bin/bash

source network-utils.sh
source ids-utils.sh

# Verify the identity of the caller
verify_identity

# Set the anchor peer for the specified organization
set_anchor_peer 