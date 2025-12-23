#!/bin/bash

# ============================================================================
# yProvTrace: Docker Container Shutdown Script
# ============================================================================
# Description:
#   Stops and removes Docker containers for a specific organization using
#   the provided docker-compose file. Supports both normal shutdown and
#   hard cleanup with volume removal.
#
# Usage:
#   ORG_CONFIG_FILE=<org-config> ./docker-down.sh <compose-file> [--hard]
#
# Arguments:
#   $1 - Path to docker-compose YAML file (required)
#   $2 - Optional: --hard flag for complete cleanup with volumes
#
# Modes:
#   Normal: Stops containers, preserves volumes
#   Hard:   Stops containers, removes volumes and orphans
#
# Requirements:
#   - Compose file must exist
#   - ORG_CONFIG_FILE must be set
#
# Exit Codes:
#   1 - Compose file not specified or not found
# ============================================================================

source docker-utils.sh

COMPOSE_FILE=$1

# Check if the compose file is provided
if [ -z "$COMPOSE_FILE" ]; then
    log_error "Compose file not specified"
    exit 1
fi

# Check if the compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Compose file '$COMPOSE_FILE' does not exist"
    exit 1
fi

# Determine shutdown mode based on --hard flag
# Check if the hard option is provided
[[ "$2" == "--hard" ]] && HARD=true || HARD=false

# Execute appropriate shutdown method
# Down the specified compose file with the appropriate method
[[ $HARD == true ]] && force_down ${COMPOSE_FILE} || down ${COMPOSE_FILE}