#!/bin/bash

set -e

source ca-utils.sh

ENROLLMENT_ID=$1
REASON=${2:-privilegewithdrawn}

if [[ -z "${ENROLLMENT_ID}" ]]; then
    log_error "Usage: ca-revoke-user.sh <id> [reason]"
    exit 1
fi
if [[ "${ENROLLMENT_ID}" == "${ORG_CA_ADMIN_USER}" ]]; then
    log_error "Refusing to revoke the bootstrap CA administrator with this script."
    exit 1
fi

require_enrolled_ca_admin
ca_client revoke -e "${ENROLLMENT_ID}" -r "${REASON}" --gencrl --mspdir "${ORG_CA_ADMIN_MSP}"
stage_crl
log_success "Identity '${ENROLLMENT_ID}' disabled and its certificates revoked"
