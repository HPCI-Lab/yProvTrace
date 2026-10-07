#!/bin/bash

set -e

source ca-utils.sh

enroll_ca_admin
log_success "CA administrator enrolled for ${ORG_DOMAIN}"
