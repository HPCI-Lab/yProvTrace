#!/bin/bash

# ============================================================================
# yProvTrace: Docker Container Startup Script
# ============================================================================
# Description:
#   Starts Docker containers for a specific organization using the provided
#   docker-compose file. This script is the entry point for launching peers,
#   orderers, or other Fabric components.
#
# Usage:
#   ORG_CONFIG_FILE=<org-config> ./docker-up.sh <compose-file>
#
# Arguments:
#   $1 - Path to docker-compose YAML file (required)
#
# Requirements:
#   - Docker must be installed and running
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

# Start the containers using docker-compose
up ${COMPOSE_FILE}