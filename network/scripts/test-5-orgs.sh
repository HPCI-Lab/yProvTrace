#!/bin/bash

. set-env.sh

# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord3.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org3.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" --hard # Added later on, removed for simplicity to avoid issues
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org5.yaml" --hard
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

# Test the chaincode functions
# ./chaincode-invoke.sh "org1.testbed.local" 1  # TODO: set identity as environment variable
# ./chaincode-query.sh "org1.testbed.local" 1  # TODO: set identity as environment variable

sleep 5

# Now, organization 4 wants to join the network (the flow of actions is strictly defined and must be followed in this order):
# 1. The new organization needs to create its credentials and public identity
# 2. The new organization starts its containers
# 3. A network participant needs to create a join request for the new organization
# 4. The participant needs to approve the join request by signing it
# 5. A participant needs to submit the join request to the orderer
# 6. The new organization needs to join the channel
# 7. The new organization needs to set the anchor peer
# 8. The new organization needs to install the chaincode
# 9. All the organizations need to approve the chaincode
# 10. Commit the chaincode (only one) to include the new organization in the endorsment policy (i.e. use the chaincode)

# 1. Credentials and public identity creation
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org4.yaml" "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Done by organization 4

# 2. Start the containers for organization 4
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Start the containers for organization 4

# 3. Create a join request for the new organization
./network-join-request.sh "${NETWORK_CTX_PATH}/org4/configtx.yaml" "org1.testbed.local" # TODO: set identity as environment variable

# 4. Approve the join request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org2.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org3.testbed.local" # TODO: set identity as environment variable

# 5. Submit the join request to the orderer (only once)
./network-commit-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

# 6. The new organization 4 needs to join the channel and install the chaincode
./network-join-organization.sh "org4.testbed.local" # TODO: set identity as environment variable

# 7. Set the anchor peer for organization 4 [to match the gossip bootstrap address in the compose file]
./network-set-anchor-peer.sh "org4.testbed.local" 1 # TODO: set identity as environment variable, assuming peer ID 1 is the anchor peer

# 8. Install and approve the chaincode for organization 4
./chaincode-install.sh "org4.testbed.local"          # TODO: set identity as environment variable

# 9. Approve the chaincode for all organizations
./chaincode-approve.sh "org1.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org2.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org3.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org4.testbed.local"          # TODO: set identity as environment variable

# 10. Commit the chaincode to include the new organization in the endorsement policy
./chaincode-commit.sh "org1.testbed.local"           # TODO: set identity as environment variable

# Test the chaincode invocation with the new organization
# ./chaincode-invoke.sh "org4.testbed.local" ${DEFAULT_PEER_ID}         # TODO: set identity as environment variable

sleep 5 

# 1. Credentials and public identity creation
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org5.yaml" "${NETWORK_CMP_PATH}/docker-compose-org5.yaml" # Done by organization 5

# 2. Start the containers for organization 5
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org5.yaml" # Start the containers for organization 5

# 3. Create a join request for the new organization
./network-join-request.sh "${NETWORK_CTX_PATH}/org5/configtx.yaml" "org1.testbed.local" # TODO: set identity as environment variable

# 4. Approve the join request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org5_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org5_update_in_envelope.pb" "org2.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org5_update_in_envelope.pb" "org3.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org5_update_in_envelope.pb" "org4.testbed.local" # TODO: set identity as environment variable

# 5. Submit the join request to the orderer (only once)
./network-commit-update.sh "${NETWORK_CHN_PATH}/org5_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

# 6. The new organization 5 needs to join the channel and install the chaincode
./network-join-organization.sh "org5.testbed.local" # TODO: set identity as environment variable

# 7. Set the anchor peer for organization 5 [to match the gossip bootstrap address in the compose file]
./network-set-anchor-peer.sh "org5.testbed.local" ${DEFAULT_PEER_ID} # TODO: set identity as environment variable, assuming peer ID 1 is the anchor peer

# 8. Install and approve the chaincode for organization 5
./chaincode-install.sh "org5.testbed.local"          # TODO: set identity as environment variable

# 9. Approve the chaincode for all organizations
./chaincode-approve.sh "org1.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org2.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org3.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org4.testbed.local"          # TODO: set identity as environment variable
./chaincode-approve.sh "org5.testbed.local"          # TODO: set identity as environment variable

# 10. Commit the chaincode to include the new organization in the endorsement policy
./chaincode-commit.sh "org1.testbed.local"           # TODO: set identity as environment variable

# Test the chaincode invocation with the new organization
# ./chaincode-invoke.sh "org4.testbed.local" ${DEFAULT_PEER_ID}         # TODO: set identity as environment variable