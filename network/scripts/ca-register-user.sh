#!/bin/bash

set -e

source ca-utils.sh

ENROLLMENT_ID=$1
ENROLLMENT_SECRET=$2
IDENTITY_TYPE=${3:-client}
AFFILIATION=${4:-}
ATTRIBUTES=${5:-}

if [[ -z "${ENROLLMENT_ID}" || -z "${ENROLLMENT_SECRET}" ]]; then
    log_error "Usage: ca-register-user.sh <id> <secret> [client|admin] [affiliation] [attributes]"
    exit 1
fi
if [[ "${IDENTITY_TYPE}" != "client" && "${IDENTITY_TYPE}" != "admin" ]]; then
    log_error "ca-register-user.sh accepts only client or admin identities. Node provisioning is handled by network-prepare.sh."
    exit 1
fi

require_enrolled_ca_admin
register_identity "${ENROLLMENT_ID}" "${ENROLLMENT_SECRET}" "${IDENTITY_TYPE}" "${AFFILIATION}" "${ATTRIBUTES}"
log_success "Identity '${ENROLLMENT_ID}' registered as ${IDENTITY_TYPE}"
