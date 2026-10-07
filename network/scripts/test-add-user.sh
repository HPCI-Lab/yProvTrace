#!/bin/bash

# Register and enroll an Org1 application user, then query the chaincode with
# that user's MSP rather than the organization administrator's MSP.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

export ORG_CONFIG_FILE="${SCRIPT_DIR}/../config/crypto/peer1.yaml"
export ORG_CA_ADMIN_PASSWORD="${ORG_CA_ADMIN_PASSWORD:-test-ca-admin-password}"

source common.sh

USER_NAME="alice"
USER_SECRET="${ALICE_ENROLLMENT_SECRET:-alicepw}"
USER_MSP="$(get_org_dir)/users/${USER_NAME}@${ORG_DOMAIN}/msp"

log_info "Registering ${USER_NAME} as an Org1 application user"
./ca-register-user.sh "${USER_NAME}" "${USER_SECRET}" client
./ca-enroll-user.sh "${USER_NAME}" "${USER_SECRET}" "${USER_MSP}"

log_info "Querying the chaincode as ${USER_NAME}"
export CORE_PEER_MSPCONFIGPATH_OVERRIDE="${USER_MSP}"
./chaincode-query.sh

log_success "User '${USER_NAME}' was created in Org1 and queried the chaincode successfully"
