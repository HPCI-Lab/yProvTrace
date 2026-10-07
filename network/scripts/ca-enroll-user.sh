#!/bin/bash

set -e

source ca-utils.sh

ENROLLMENT_ID=$1
ENROLLMENT_SECRET=$2
OUTPUT_DIR=${3:-}

if [[ -z "${ENROLLMENT_ID}" || -z "${ENROLLMENT_SECRET}" ]]; then
    log_error "Usage: ca-enroll-user.sh <id> <secret> [output-msp-directory]"
    exit 1
fi

enroll_identity "${ENROLLMENT_ID}" "${ENROLLMENT_SECRET}" "${OUTPUT_DIR:-$(get_org_dir)/users/${ENROLLMENT_ID}@${ORG_DOMAIN}/msp}"
