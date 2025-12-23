#!/bin/bash

# ============================================================================
# yProvTrace: Chaincode Installation Script
# ============================================================================
# Description:
#   Installs a packaged chaincode on the peer of the current organization.
#   The chaincode package must be created before running this script.
#
# Requirements:
#   - Organization identity must be valid
#   - Chaincode must be packaged (*.tar.gz file)
#   - ORG_CONFIG_FILE must be set
#   - Peer must be running and accessible
#
# Steps:
#   1. Verify organization identity
#   2. Resolve chaincode sequence number
#   3. Install chaincode package on peer
# ============================================================================

source ids-utils.sh
source cc-utils.sh

# Verify the identity of the caller
verify_identity

# Resolve the sequence number for the chaincode
resolveSequence

# Install the chaincode
install_chaincode