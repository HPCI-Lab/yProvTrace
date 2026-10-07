#!/bin/bash

set -e

source ca-utils.sh
source ids-utils.sh
source crypto-utils.sh

enroll_ca_admin
provision_organization
generate_endpoints
generate_ccp

log_success "CA-generated MSP, node, TLS, and admin identities prepared for ${ORG_DOMAIN}"
