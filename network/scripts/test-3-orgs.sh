#!/bin/bash

. set-env.sh

# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord3.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org3.yaml" --hard
# -----------------------

rm -rf ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}

# -----------------------

# Setup the crypto material
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-ord1.yaml" "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml"
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-ord2.yaml" "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml"
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-ord3.yaml" "${NETWORK_CMP_PATH}/docker-compose-ord3.yaml"
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org1.yaml" "${NETWORK_CMP_PATH}/docker-compose-org1.yaml"
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org2.yaml" "${NETWORK_CMP_PATH}/docker-compose-org2.yaml"
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org3.yaml" "${NETWORK_CMP_PATH}/docker-compose-org3.yaml"

# NOTE: This needs to be done only once, when all the crypto material is generated and shared.
# NOTE: Identities folder must exist and be populated with certificates.
./network-init.sh

# Docker setup
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" # Start the orderer 1
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" # Start the orderer 2
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-ord3.yaml" # Start the orderer 3
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" # Start the organization 1
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org2.yaml" # Start the organization 2
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org3.yaml" # Start the organization 3

# Channel setup
./network-join-orderer.sh "orderer.ord1.testbed.local"  # TODO: set identity as environment variable
./network-join-orderer.sh "orderer.ord2.testbed.local"  # TODO: set identity as environment variable
./network-join-orderer.sh "orderer.ord3.testbed.local"  # TODO: set identity as environment variable
./network-join-organization.sh "org1.testbed.local"     # TODO: set identity as environment variable
./network-join-organization.sh "org2.testbed.local"     # TODO: set identity as environment variable
./network-join-organization.sh "org3.testbed.local"     # TODO: set identity as environment variable


# Install the chaincode on all peers of all organizations
./chaincode-install.sh "org1.testbed.local" # TODO: set identity as environment variable
./chaincode-install.sh "org2.testbed.local" # TODO: set identity as environment variable
./chaincode-install.sh "org3.testbed.local" # TODO: set identity as environment variable

# Approve the chaincode for each organization (only once)
./chaincode-approve.sh "org1.testbed.local" # TODO: set identity as environment variable
./chaincode-approve.sh "org2.testbed.local" # TODO: set identity as environment variable
./chaincode-approve.sh "org3.testbed.local" # TODO: set identity as environment variable

# Commit the chaincode definition to the channel (only once)
./chaincode-commit.sh "org1.testbed.local" # TODO: set identity as environment variable