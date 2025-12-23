#!/bin/bash

# ============================================================================
# yProvTrace: Anchor Peer Configuration Script
# ============================================================================
# Description:
#   Sets the anchor peer for an organization in the channel configuration.
#   Anchor peers are used for cross-organization gossip communication and
#   service discovery.
#
# Purpose:
#   Anchor peers enable:
#   - Cross-organization peer discovery
#   - Gossip protocol bootstrap across organizations
#   - External service endpoints for client applications
#
# Requirements:
#   - Organization must be member of the channel
#   - Peer must be running and joined to channel
#   - Organization identity must be valid
#   - ORG_CONFIG_FILE must be set
#
# Process:
#   1. Verify organization identity
#   2. Fetch current channel configuration
#   3. Add anchor peer definition
#   4. Create and commit update transaction
#
# Note: Anchor peer should match the gossip bootstrap address in docker-compose
#
# Exit Codes:
#   1 - Identity verification or anchor peer update failed
# ============================================================================

source network-utils.sh
source ids-utils.sh

# Verify the identity of the caller
verify_identity

# Set the anchor peer configuration for the organization
set_anchor_peer