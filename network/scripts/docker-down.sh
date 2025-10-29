#!/bin/bash

. docker-utils.sh

COMPOSE_FILE=$1

# Check if the hard option is provided
[[ "$2" == "--hard" ]] && HARD=true || HARD=false

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

# Down the specified compose file with the appropriate method
[[ $HARD == true ]] && force_down ${COMPOSE_FILE} || down ${COMPOSE_FILE}