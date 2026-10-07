#!/bin/bash

# Add Org4 to the running three-peer network created by test-3-orgs.sh,
# update the chaincode definition, and run an Org4 chaincode smoke test.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

export ORG_CONFIG_FILE="NONE"
source common.sh

export ORG_CA_ADMIN_PASSWORD="${ORG_CA_ADMIN_PASSWORD:-test-ca-admin-password}"

ORG4_UPDATE="${NETWORK_CHN_PATH}/org4_update_in_envelope.pb"

log_info "Preparing and starting Org4"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer4.yaml"
./network-prepare.sh "${ORG_CONFIG_FILE}"
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer4.yaml"

log_info "Adding Org4 to the channel with majority approval"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/org4/configtx.yaml"
./network-approve-update.sh "${ORG4_UPDATE}"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-approve-update.sh "${ORG4_UPDATE}"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-commit-update.sh "${ORG4_UPDATE}"

log_info "Joining Org4 and installing the chaincode"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer4.yaml"
./network-join-peer.sh
./network-set-anchor-peer.sh
./chaincode-install.sh

log_info "Approving and committing the updated chaincode definition"
for organization in peer1 peer2 peer3 peer4; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" ./chaincode-approve.sh
done

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./chaincode-commit.sh

log_info "Testing cc-test-v2 from Org4"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer4.yaml"
./test-chaincode-v2.sh

log_success "Org4 joined the network and queried the chaincode successfully"
