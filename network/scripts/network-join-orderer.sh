#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORD_HOSTNAME=$1

# Check if orderer hostname is provided
if [ -z "$ORD_HOSTNAME" ]; then
    echo "Usage: $0 <orderer_hostname>"
    exit 1
fi

# Verify the identity of the caller
ORD_DOMAIN=$(echo "$ORD_HOSTNAME" | cut -d'.' -f2-)
verify_identity "$ORD_DOMAIN"

# Join the orderer to the network
join_orderer ${ORD_HOSTNAME}