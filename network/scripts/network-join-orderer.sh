#!/bin/bash

# ============================================================================
# yProvTrace: Orderer Channel Join Script
# ============================================================================
# Description:
#   Joins an orderer node to the application channel using the osnadmin
#   channel management API. This makes the orderer part of the consensus
#   cluster for the channel.
#
# Requirements:
#   - Orderer container must be running
#   - Genesis block must exist (created by network-init.sh)
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must point to an orderer organization
#
# Process:
#   1. Verify organization identity (admin credentials)
#   2. Join orderer to channel using genesis block
#
# Uses:
#   osnadmin CLI with TLS client certificates for authentication
#
# Exit Codes:
#   1 - Identity verification or join operation failed
# ============================================================================

source ids-utils.sh
source network-utils.sh

# Verify the identity of the caller
verify_identity 

# Join the orderer to the channel using the genesis block
# Join the orderer to the network
join_orderer