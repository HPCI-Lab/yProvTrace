#!/bin/bash

# ============================================================================
# yProvTrace: Peer Channel Join Script
# ============================================================================
# Description:
#   Joins a peer node to the application channel using the genesis block.
#   This allows the peer to participate in the network and maintain a
#   copy of the ledger.
#
# Requirements:
#   - Peer container must be running
#   - Genesis block must exist (created by network-init.sh)
#   - Organization must be part of channel configuration
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must point to a peer organization
#
# Process:
#   1. Verify organization identity (admin credentials)
#   2. Join peer to channel using genesis block
#
# Note: For new organizations joining an existing channel, they must first
#       be added via network-join-request.sh before their peers can join
#
# Exit Codes:
#   1 - Identity verification or join operation failed
# ============================================================================

source ids-utils.sh
source network-utils.sh

# Verify the identity of the caller
verify_identity

# Join the organization to the network
join_peer 