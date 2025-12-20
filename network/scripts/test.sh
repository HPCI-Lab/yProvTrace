#!/bin/bash

# ============================================================================
# Test Description:
# This script sets up a Hyperledger Fabric network with:
#   - One peer organization 'peer1'
#   - Three orderer organizations
#
# It then:
#   1. Deploys a chaincode and tests its functionality
#   2. Allows a new organization 'peer2' to join the network
#   3. Removes that organization from the network
#   4. Verifies chaincode functionality before and after join/leave
# ============================================================================

source common.sh

# ---- For test only ----
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer1.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer2.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer3.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer2.yaml" --hard
# -----------------------

sudo rm -rf ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}

# -----------------------

# Setup the crypto material
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer1.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer2.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer3.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/peer1.yaml"

# NOTE: This needs to be done only once, when all the crypto material is generated and shared.
# NOTE: Identities folder must exist and be populated with certificates.
./network-init.sh

# Docker setup
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer1.yaml" # Start the orderer 1

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer2.yaml" # Start the orderer 2

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer3.yaml" # Start the orderer 3

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" # Start the organization 1

# Channel setup
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./network-join-orderer.sh

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-peer.sh

# Install the chaincode on all peers of all organizations
./chaincode-install.sh

# Approve the chaincode for each organization (only once)
./chaincode-approve.sh

# Commit the chaincode definition to the channel (only once)
./chaincode-commit.sh

# Test the chaincode functions
./chaincode-invoke.sh
sleep 5
./chaincode-query.sh

# Now, organization 'peer2' wants to join the network (the flow of actions is strictly defined and must be followed in this order):
# 1. The new organization needs to create its credentials and public identity
# 2. The new organization starts its containers
# 3. A network participant needs to create a join request for the new organization
# 4. The participant needs to approve the join request by signing it
# 5. A participant needs to submit the join request to the orderer
# 6. The new organization needs to join the channel
# 7. The new organization needs to set the anchor peer
# 8. The new organization needs to install the chaincode
# 9. All the organizations need to approve the chaincode
# 10. Commit the chaincode (only one) to include the new organization in the endorsement policy (i.e. use the chaincode)

# 1. Credentials and public identity creation

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer2.yaml" # Prepare the crypto material for organization 2

# 2. Start the containers for organization 2
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer2.yaml" # Start the containers for organization 2

# 3. Create a join request for the new organization
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/joining/configtx.yaml"

# 4. Approve the join request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# 5. Submit the join request to the orderer (only once)
./network-commit-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# 6. The new organization 2 needs to join the channel and install the chaincode
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-join-peer.sh

# 7. Set the anchor peer for organization 2 [to match the gossip bootstrap address in the compose file]
./network-set-anchor-peer.sh

# 8. Install and approve the chaincode for organization 2
./chaincode-install.sh 

# 9. Approve the chaincode for organization 2
./chaincode-approve.sh

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./chaincode-approve.sh # approve again from org1

# 10. Commit the chaincode to include the new organization in the endorsement policy
./chaincode-commit.sh

# Test the chaincode invocation with the new organization
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml" \
    ./chaincode-invoke.sh

sleep 5 

# Remove the new organization 2 from the network
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-leave-request.sh "${NETWORK_CTX_PATH}/joining/configtx.yaml"

# Approve the removal of organization 2 from the channel
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# Commit the removal of organization 2 from the channel
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# Remove the organization 2 crypto material and public identity
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-leave-organization.sh --hard

# ---- For test only ----
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer1.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer2.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer3.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer2.yaml" --hard
# -----------------------