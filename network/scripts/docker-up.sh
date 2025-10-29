#!/bin/bash

. docker-utils.sh

COMPOSE_FILE=$1

# Check if the compose file is provided
if [ -z "$COMPOSE_FILE" ]; then
    echo "Usage: $0 <compose-file>"
    exit 1
fi

# Check if the compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: Compose file $COMPOSE_FILE does not exist."
    exit 1
fi

up ${COMPOSE_FILE}