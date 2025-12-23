#!/bin/bash

# ============================================================================
# yProvTrace: Chaincode Commit Script
# ============================================================================
# Description:
#   Commits the chaincode definition to the channel after sufficient
#   organizations have approved it. This finalizes the chaincode deployment
#   and makes it available for invocation by all channel members.
#
# Requirements:
#   - Organization identity must be valid
#   - Majority of organizations must have approved
#   - ORG_CONFIG_FILE must be set
#
# Steps:
#   1. Verify organization identity
#   2. Resolve chaincode sequence number
#   3. Check commit readiness across organizations
#   4. Commit chaincode definition to channel
# ============================================================================

source cc-utils.sh

# Verify the identity of the caller
verify_identity

# Resolve the sequence number for the chaincode
resolveSequence

# Check the commit readiness of the chaincode
check_commit_readiness

# Commit the chaincode
commit_chaincode