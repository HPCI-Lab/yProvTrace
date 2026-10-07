#!/bin/bash

set -e

source ca-utils.sh

require_ca_admin_password
mkdir -p "${ORG_CA_HOME}"

docker compose -f "${ORG_CA_COMPOSE_FILE}" -p "${ORG_CA_DOCKER_PROJECT}" up -d

for attempt in $(seq 1 30); do
    [[ -f "${ORG_CA_CERT_FILE}" ]] && break
    sleep 1
done
if [[ ! -f "${ORG_CA_CERT_FILE}" ]]; then
    log_error "Fabric CA did not create ${ORG_CA_CERT_FILE} within 30 seconds."
    exit 1
fi
log_success "Fabric CA for ${ORG_DOMAIN} is available at ${ORG_CA_URL}"
