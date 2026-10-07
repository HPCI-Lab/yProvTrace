#!/bin/bash

set -e

source ca-utils.sh

ENROLLMENT_ID=$1
MSP_DIR=${2:-"$(get_org_dir)/users/${ENROLLMENT_ID}@${ORG_DOMAIN}/msp"}

if [[ -z "${ENROLLMENT_ID}" || ! -d "${MSP_DIR}" ]]; then
    log_error "Usage: ca-reenroll-user.sh <id> [existing-msp-directory]"
    exit 1
fi

ca_client reenroll --mspdir "${MSP_DIR}"
cp "${ORG_CA_CERT_FILE}" "${MSP_DIR}/cacerts/ca.${ORG_DOMAIN}-cert.pem"
cp "$(get_org_dir)/msp/config.yaml" "${MSP_DIR}/config.yaml"
log_success "Identity '${ENROLLMENT_ID}' re-enrolled"
