#!/bin/bash

# Exercise cc-test-v2 on an already-running Fabric network.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

source common.sh
source ids-utils.sh

if [[ "${CHAINCODE_NAME}" != "cc-test-v2" ]]; then
    log_error "This test requires network.chaincode.name to be 'cc-test-v2', not '${CHAINCODE_NAME}'."
    exit 1
fi

get_default_orderer
export ALLOW_MSP_SIGNER_OVERRIDE=true
set_peer_env

SIGNING_CERT="$(find "${CORE_PEER_MSPCONFIGPATH}/signcerts" -maxdepth 1 -type f | head -n 1)"
if [[ ! -f "${SIGNING_CERT}" ]]; then
    log_error "No signing certificate found in ${CORE_PEER_MSPCONFIGPATH}/signcerts."
    exit 1
fi

# This is the same identity representation returned by
# ctx.clientIdentity.getID() inside the Node.js Fabric contract API.
CALLER_SUBJECT="$(openssl x509 -in "${SIGNING_CERT}" -noout -subject -nameopt compat | sed 's/^subject=//')"
CALLER_ISSUER="$(openssl x509 -in "${SIGNING_CERT}" -noout -issuer -nameopt compat | sed 's/^issuer=//')"
CALLER_ID="x509::${CALLER_SUBJECT}::${CALLER_ISSUER}"

TLS_IDENTITIES="$(get_tls_identities)"
TEST_STARTED_AT="$(date +%s)"
PID="${1:-v2_test_${ORG_MSP_ID}_$(date +%s%N)}"
URI="https://example.com/resource/${PID}"
HASH="$(printf '%s' "${PID}${URI}${TEST_STARTED_AT}" | sha256sum | cut -d' ' -f1)"
OWNERS="$(jq -cn --arg owner "${CALLER_ID}" '[$owner]')"

invoke_v2() {
    local payload="$1"
    peer chaincode invoke \
        -o "${ORDERER_ADDRESS}" \
        --ordererTLSHostnameOverride "${ORDERER_HOSTNAME}" \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --tls \
        --cafile "${ORDERER_TLS_CA}" \
        ${TLS_IDENTITIES} \
        --waitForEvent \
        -c "${payload}"
}

query_v2() {
    local payload="$1"
    peer chaincode query \
        -C "${CHANNEL_NAME}" \
        -n "${CHAINCODE_NAME}" \
        --tls \
        --peerAddresses "${CORE_PEER_ADDRESS}" \
        --tlsRootCertFiles "${CORE_PEER_TLS_ROOTCERT_FILE}" \
        -c "${payload}"
}

log_info "Creating V2 resource '${PID}' owned by the invoking user"
CREATE_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:CreateResource' \
    --arg pid "${PID}" \
    --arg uri "${URI}" \
    --arg hash "${HASH}" \
    --arg owners "${OWNERS}" \
    '{Function:$function, Args:[$pid,$uri,$hash,$owners]}')"
invoke_v2 "${CREATE_PAYLOAD}"

READ_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:ReadResource' \
    --arg pid "${PID}" \
    '{Function:$function, Args:[$pid]}')"
RESOURCE="$(query_v2 "${READ_PAYLOAD}")"
jq -e \
    --arg pid "${PID}" \
    --arg owner "${CALLER_ID}" \
    '(has("docType") | not) and (has("clientTimestamp") | not) and .pid == $pid and .status == 0 and .creator.id == $owner and (.owners | index($owner) != null)' \
    <<<"${RESOURCE}" >/dev/null

log_info "Advancing '${PID}' from UNKNOWN to VALID"
VALID_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:UpdateResourceStatus' \
    --arg pid "${PID}" \
    '{Function:$function, Args:[$pid,"1"]}')"
invoke_v2 "${VALID_PAYLOAD}"

log_info "Advancing '${PID}' from VALID to REVOKED"
REVOKED_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:UpdateResourceStatus' \
    --arg pid "${PID}" \
    '{Function:$function, Args:[$pid,"2"]}')"
invoke_v2 "${REVOKED_PAYLOAD}"

RESOURCE="$(query_v2 "${READ_PAYLOAD}")"
jq -e '.status == 2 and .updatedBy.id and .updatedAt' <<<"${RESOURCE}" >/dev/null

log_info "Confirming that REVOKED cannot transition back to VALID"
if invoke_v2 "${VALID_PAYLOAD}" >/dev/null 2>&1; then
    log_error "The invalid REVOKED-to-VALID transition unexpectedly succeeded."
    exit 1
fi

TEST_FINISHED_AT="$(date +%s)"
RANGE_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:GetResourcesByTimestamp' \
    --arg start "${TEST_STARTED_AT}" \
    --arg end "${TEST_FINISHED_AT}" \
    '{Function:$function, Args:[$start,$end]}')"
RANGE_RESULTS="$(query_v2 "${RANGE_PAYLOAD}")"
jq -e --arg pid "${PID}" 'any(.[]; .pid == $pid)' <<<"${RANGE_RESULTS}" >/dev/null

HISTORY_PAYLOAD="$(jq -cn \
    --arg function 'ResourceEventsV2:GetResourceHistory' \
    --arg pid "${PID}" \
    '{Function:$function, Args:[$pid]}')"
HISTORY="$(query_v2 "${HISTORY_PAYLOAD}")"
jq -e 'length >= 3 and .[0].txId and .[-1].txId' <<<"${HISTORY}" >/dev/null

log_success "cc-test-v2 passed for '${PID}': create, read, transitions, index, and history."
