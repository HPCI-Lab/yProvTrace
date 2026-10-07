#!/bin/bash

# Prepare a fresh organization using Fabric CA by default. The legacy
# cryptogen flow remains available with --cryptogen for development only.

set -e

MODE="ca"
if [[ "$1" == "--cryptogen" ]]; then
    MODE="cryptogen"
    shift
fi

# No argument prepares the complete default topology. Each organization runs
# in a child process so its ORG_* and CA settings remain isolated.
if [[ -z "$1" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    CONFIG_DIR="${SCRIPT_DIR}/../config/crypto"
    DEFAULT_ORGANIZATIONS=(orderer1 orderer2 orderer3 peer1 peer2 peer3)

    if [[ "${MODE}" == "ca" && -z "${ORG_CA_ADMIN_PASSWORD}" ]]; then
        echo "ORG_CA_ADMIN_PASSWORD must be set in the environment." >&2
        exit 1
    fi

    for organization in "${DEFAULT_ORGANIZATIONS[@]}"; do
        config_file="${CONFIG_DIR}/${organization}.yaml"
        echo "Preparing ${organization} with ${MODE}..."
        if [[ "${MODE}" == "cryptogen" ]]; then
            ORG_CONFIG_FILE="${config_file}" "${SCRIPT_DIR}/network-prepare.sh" --cryptogen "${config_file}"
        else
            ORG_CONFIG_FILE="${config_file}" "${SCRIPT_DIR}/network-prepare.sh" "${config_file}"
        fi
    done

    echo "Prepared 3 peer organizations and 3 ordering organizations."
    exit 0
fi

ORG_CONFIG_FILE=$1
if [[ -z "${ORG_CONFIG_FILE}" || ! -f "${ORG_CONFIG_FILE}" ]]; then
    echo "Usage: network-prepare.sh [--cryptogen] [organization-config.yaml]" >&2
    exit 1
fi
export ORG_CONFIG_FILE

if [[ "${MODE}" == "cryptogen" ]]; then
    source crypto-utils.sh
    source ids-utils.sh
    generate_crypto "${ORG_CONFIG_FILE}"
    copy_msp_folder
    generate_endpoints
    generate_ccp
    exit 0
fi

source ca-utils.sh
source ids-utils.sh
source crypto-utils.sh

require_ca_admin_password
mkdir -p "${ORG_CA_HOME}"
docker compose -f "${ORG_CA_COMPOSE_FILE}" -p "${ORG_CA_DOCKER_PROJECT}" up -d

for attempt in $(seq 1 30); do
    [[ -f "${ORG_CA_CERT_FILE}" ]] && break
    sleep 1
done
if [[ ! -f "${ORG_CA_CERT_FILE}" ]]; then
    log_error "Fabric CA failed to initialize. Inspect container ${ORG_CA_HOSTNAME}."
    exit 1
fi

enroll_ca_admin
provision_organization
generate_endpoints
generate_ccp
log_success "Organization ${ORG_DOMAIN} prepared with Fabric CA identities"
