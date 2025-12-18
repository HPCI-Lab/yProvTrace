#!/bin/bash

source ids-utils.sh
source network-utils.sh

# Verify the identity of the caller
verify_identity 

# Join the orderer to the network
join_orderer