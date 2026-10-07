#!/bin/bash

set -e

source ca-utils.sh

docker compose -f "${ORG_CA_COMPOSE_FILE}" -p "${ORG_CA_DOCKER_PROJECT}" down
