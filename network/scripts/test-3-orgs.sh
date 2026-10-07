#!/bin/bash

# Complete example:
#   - three independent ordering organizations
#   - three peer organizations added incrementally to the channel
#   - exactly one Fabric network admin per organization
#   - no pre-created application users
#   - chaincode installed and approved by all peer organizations
#
# The network and all six Fabric CAs remain running when the script completes.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

export ORG_CONFIG_FILE="NONE"
source common.sh

# Development default. Set this explicitly before running outside a local test.
export ORG_CA_ADMIN_PASSWORD="${ORG_CA_ADMIN_PASSWORD:-test-ca-admin-password}"

ORDERER_ORGS=(orderer1 orderer2 orderer3)
PEER_ORGS=(peer1 peer2 peer3)
ALL_ORGS=("${ORDERER_ORGS[@]}" "${PEER_ORGS[@]}")

log_info "Cleaning previous 3-organization test network"
for organization in "${ALL_ORGS[@]}"; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" \
        ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-${organization}.yaml" --hard || true
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" \
        ./ca-down.sh || true
done

# Generated identity and CA state can be owned by container users.
sudo rm -rf \
    "${NETWORK_ORG_PATH}" \
    "${NETWORK_IDS_PATH}" \
    "${NETWORK_CHN_PATH}" \
    "${NETWORK_CA_PATH}" \
    "${NETWORK_PKG_PATH}"
mkdir -p \
    "${NETWORK_ORG_PATH}" \
    "${NETWORK_IDS_PATH}" \
    "${NETWORK_CHN_PATH}" \
    "${NETWORK_PKG_PATH}"

log_info "Preparing the three orderers and founding peer organization with Fabric CA"
for organization in "${ORDERER_ORGS[@]}" peer1; do
    ./network-prepare.sh "${NETWORK_CRP_PATH}/${organization}.yaml"
done

log_info "Generating the initial channel block"
export ORG_CONFIG_FILE="NONE"
./network-init.sh

log_info "Starting and joining the three orderers"
for organization in "${ORDERER_ORGS[@]}"; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" \
        ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-${organization}.yaml"
done
for organization in "${ORDERER_ORGS[@]}"; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" \
        ./network-join-orderer.sh
done

log_info "Starting Org1 as the founding application organization"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml"
./network-join-peer.sh

log_info "Packaging and deploying chaincode on Org1"
./chaincode-package.sh
./chaincode-install.sh
./chaincode-approve.sh
./chaincode-commit.sh

log_info "Adding Org2 through a channel configuration update"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer2.yaml"
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer2.yaml"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/org2/configtx.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-join-peer.sh
./network-set-anchor-peer.sh
./chaincode-install.sh

log_info "Adding Org3 with majority approval from Org1 and Org2"
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer3.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer3.yaml"
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer3.yaml"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/org3/configtx.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer3.yaml"
./network-join-peer.sh
./network-set-anchor-peer.sh
./chaincode-install.sh

log_info "Approving the final chaincode definition from all peer organizations"
for organization in "${PEER_ORGS[@]}"; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${organization}.yaml" ./chaincode-approve.sh
done

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./chaincode-commit.sh

log_info "Creating the Org1 application user through test-add-user.sh"
./test-add-user.sh

# test-add-user.sh runs in a child process, so reload peer1's derived
# organization variables in this parent shell before resolving Alice's MSP.
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
select_organization

CHAINCODE_USER="alice"
CHAINCODE_USER_MSP="$(get_org_dir)/users/${CHAINCODE_USER}@${ORG_DOMAIN}/msp"
log_info "Running cc-test-v2 as application user '${CHAINCODE_USER}'"
CORE_PEER_MSPCONFIGPATH_OVERRIDE="${CHAINCODE_USER_MSP}" ./test-chaincode-v2.sh

log_success "3-peer/3-orderer CA-backed network is running"
log_info "Application user '${CHAINCODE_USER}' was enrolled in Org1 and used to test cc-test-v2."
