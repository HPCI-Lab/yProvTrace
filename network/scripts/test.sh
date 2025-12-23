#!/bin/bash

# ============================================================================
# yProvTrace: Comprehensive Network Integration Test
# ============================================================================
# Description:
#   This script automates a full lifecycle test of the yProvTrace network:
#   1. Bootstraps a base network (1 Peer Org, 3 Orderer Orgs).
#   2. Deploys and verifies the 'cc-test' chaincode.
#   3. Dynamically adds a second organization ('peer2') to the running channel.
#   4. Re-configures the chaincode endorsement for the new member.
#   5. Dynamically removes 'peer2' and cleans up the environment.
# ============================================================================

source common.sh

# ----------------------------------------------------------------------------
# PHASE 1: Environment Cleanup & Pre-flight Checks
# ----------------------------------------------------------------------------

# Ensure any existing containers and volumes are purged before starting
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

# Wipe existing ledger data, channel artifacts, and identity certificates
sudo rm -rf ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}

# ----------------------------------------------------------------------------
# PHASE 2: Crypto Material Generation & Network Genesis
# ----------------------------------------------------------------------------

# Generate local MSP material and share public certificates for base members
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer1.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer2.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/orderer3.yaml"

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./network-prepare.sh "${NETWORK_CRP_PATH}/peer1.yaml"

# Leader Org generates the Genesis Block for the system/application channel
./network-init.sh

# ----------------------------------------------------------------------------
# PHASE 3: Network Startup & Channel Joining
# ----------------------------------------------------------------------------

# Launch all orderer and peer containers
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer1.yaml" # Start the orderer 1

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer2.yaml" # Start the orderer 2

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-orderer3.yaml" # Start the orderer 3

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" # Start the organization 1

# All orderers join the channel
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./network-join-orderer.sh

# Peer organization joins the channel
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-peer.sh

# ----------------------------------------------------------------------------
# PHASE 4: Chaincode Deployment (Initial)
# ----------------------------------------------------------------------------
./chaincode-install.sh # Install the chaincode on peer1
./chaincode-approve.sh # Approve the chaincode for peer1
./chaincode-commit.sh # Commit the chaincode definition

# Sanity check: Invoke a transaction and query the state
./chaincode-invoke.sh
sleep 5
./chaincode-query.sh

# ----------------------------------------------------------------------------
# PHASE 5: Dynamic Membership Expansion (Adding Peer2)
# ----------------------------------------------------------------------------

# 1. New Org generates local credentials and exports public certs
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer2.yaml" # Prepare the crypto material for organization 2

# 2. Start the peer2 container
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

# ----------------------------------------------------------------------------
# PHASE 6: Dynamic Membership Reduction (Removing Peer2)
# ----------------------------------------------------------------------------

# 1. Create a leave request for organization 2
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-leave-request.sh "${NETWORK_CTX_PATH}/joining/configtx.yaml"

# 2. Approve the leave request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# 3. Submit the leave request to the orderer (only once)
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# 4. The organization 2 leaves the channel and cleans up its data
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-leave-organization.sh --hard

# ----------------------------------------------------------------------------
# PHASE 7: Final Teardown
# ----------------------------------------------------------------------------

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