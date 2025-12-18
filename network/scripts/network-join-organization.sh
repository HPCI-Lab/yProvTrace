#!/bin/bash

source ids-utils.sh
source network-utils.sh

# Verify the identity of the caller
verify_identity

# Join the organization to the network
join_peer 