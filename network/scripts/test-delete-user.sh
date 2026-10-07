#!/bin/bash

# Revoke Alice in the Org1 CA, publish the generated CRL in the channel MSP,
# verify that her certificate is rejected, and remove her local MSP material.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

export ORG_CONFIG_FILE="${SCRIPT_DIR}/../config/crypto/peer1.yaml"
export ORG_CA_ADMIN_PASSWORD="${ORG_CA_ADMIN_PASSWORD:-test-ca-admin-password}"

source common.sh

USER_NAME="alice"
USER_MSP="$(get_org_dir)/users/${USER_NAME}@${ORG_DOMAIN}/msp"
USER_DIR="$(dirname "${USER_MSP}")"
CRL_UPDATE="${NETWORK_CHN_PATH}/org1crl_update_in_envelope.pb"

if [[ ! -d "${USER_MSP}" ]]; then
    log_error "User MSP not found: ${USER_MSP}. Run test-add-user.sh first."
    exit 1
fi

log_info "Revoking ${USER_NAME} and generating the Org1 CRL"
./ca-revoke-user.sh "${USER_NAME}" privilegewithdrawn

log_info "Creating the channel update that publishes the Org1 CRL"
./ca-create-crl-update.sh

log_info "Signing and committing the CRL update as the Org1 administrator"
./network-approve-update.sh "${CRL_UPDATE}"
./network-commit-update.sh "${CRL_UPDATE}"

log_info "Verifying that the revoked identity can no longer query the chaincode"
sleep 3
export CORE_PEER_MSPCONFIGPATH_OVERRIDE="${USER_MSP}"
if ./chaincode-query.sh; then
    unset CORE_PEER_MSPCONFIGPATH_OVERRIDE
    log_error "The query as ${USER_NAME} unexpectedly succeeded after CRL publication."
    exit 1
fi
unset CORE_PEER_MSPCONFIGPATH_OVERRIDE

log_info "Confirming that the same query still succeeds as the Org1 administrator"
./chaincode-query.sh

log_success "The network rejected ${USER_NAME}'s revoked certificate as expected"

# The CA record and ledger history remain for audit purposes. Only Alice's
# local private key and enrollment certificate are removed here.
rm -rf -- "${USER_DIR}"

log_success "User '${USER_NAME}' was revoked and local credentials were removed"
