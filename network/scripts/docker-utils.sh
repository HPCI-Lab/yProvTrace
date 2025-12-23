#!/bin/bash

# ============================================================================
# yProvTrace: Docker Utility Functions
# ============================================================================
# Description:
#   Provides wrapper functions for Docker Compose operations to manage
#   Hyperledger Fabric containers (peers, orderers, CAs, etc.).
#
# Functions:
#   - up()         : Start containers in detached mode
#   - down()       : Stop and remove containers
#   - force_down() : Stop containers and remove volumes/orphans
#
# Docker Compose Project:
#   All containers use DOCKER_PROJECT_NAME for isolation
# ============================================================================

source common.sh

# ----------------------------------------------------------------------------
# Start Containers
# ----------------------------------------------------------------------------
# Description: Launches Docker containers from a compose file
# Parameters:
#   $1 - Path to docker-compose YAML file
# Purpose: Starts Fabric components in detached mode
# ----------------------------------------------------------------------------
up() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d
}

# ----------------------------------------------------------------------------
# Stop Containers
# ----------------------------------------------------------------------------
# Description: Stops and removes containers
# Parameters:
#   $1 - Path to docker-compose YAML file
# Purpose: Clean shutdown preserving volumes
# ----------------------------------------------------------------------------
down() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} down
}

# ----------------------------------------------------------------------------
# Force Stop Containers
# ----------------------------------------------------------------------------
# Description: Stops containers and removes volumes and orphans
# Parameters:
#   $1 - Path to docker-compose YAML file
# Purpose: Complete cleanup including persistent data
# Warning: Deletes all volumes (ledger data, state databases, etc.)
# ----------------------------------------------------------------------------
force_down() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} down --volumes --remove-orphans
}