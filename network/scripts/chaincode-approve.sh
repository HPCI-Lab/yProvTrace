#!/bin/bash

# ============================================================================
# yProvTrace: Chaincode Approval Script
# ============================================================================
# Description:
#   Approves a chaincode definition for the current organization. Each
#   organization in the channel must approve the chaincode before it can
#   be committed to the channel.
#
# Requirements:
#   - Organization identity must be valid
#   - Chaincode must be installed on at least one peer
#   - ORG_CONFIG_FILE must be set
#
# Steps:
#   1. Verify organization identity
#   2. Resolve chaincode sequence number
#   3. Approve chaincode definition
# ============================================================================

source ids-utils.sh
source cc-utils.sh

# Verify the identity of the caller
verify_identity 

# Resolve the sequence number for the chaincode
resolveSequence

# Approve the chaincode for the organization
approve_chaincode