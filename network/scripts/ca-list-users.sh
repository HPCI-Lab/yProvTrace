#!/bin/bash

set -e

source ca-utils.sh

require_enrolled_ca_admin
ca_client identity list --mspdir "${ORG_CA_ADMIN_MSP}"
