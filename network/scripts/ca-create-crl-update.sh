#!/bin/bash

set -e

# Create a normal Fabric channel-config update that publishes the current
# organization's CRL. Other organization admins approve and commit it using
# the existing network-approve-update.sh/network-commit-update.sh workflow.

source network-utils.sh
source ids-utils.sh
source ca-utils.sh

CRL_FILE="$(get_identity_dir)/msp/crls/crl.pem"

if [[ ! -f "${CRL_FILE}" ]]; then
    log_error "No staged CRL found at ${CRL_FILE}. Revoke an identity first."
    exit 1
fi

verify_identity
fetch_channel_config

CRL_BASE64=$(base64 -w 0 "${CRL_FILE}")

if [[ "${ORG_TYPE}" == "peer" ]]; then
    jq --arg org "${ORG_NAME}" --arg crl "${CRL_BASE64}" \
        '.channel_group.groups.Application.groups[$org].values.MSP.value.config.revocation_list = (((.channel_group.groups.Application.groups[$org].values.MSP.value.config.revocation_list // []) + [$crl]) | unique)' \
        "${CURRENT}" > "${MODIFIED}"
else
    jq --arg org "${ORG_NAME}" --arg crl "${CRL_BASE64}" \
        '.channel_group.groups.Orderer.groups[$org].values.MSP.value.config.revocation_list = (((.channel_group.groups.Orderer.groups[$org].values.MSP.value.config.revocation_list // []) + [$crl]) | unique)' \
        "${CURRENT}" > "${MODIFIED}"
fi

if [[ ! -s "${MODIFIED}" ]]; then
    log_error "Failed to add the CRL to the decoded channel configuration."
    exit 1
fi

create_update_transaction "${ORG_NAME}CRL"
log_success "CRL update created at ${NETWORK_CHN_PATH}/${ORG_NAME,,}crl_update_in_envelope.pb"
log_info "Have the required admins sign it with network-approve-update.sh, then submit it with network-commit-update.sh."
