#!/bin/bash

# ============================================================================
# yProvTrace: 3-Organization Production-Style Setup
# ============================================================================
# Description:
#   1. Bootstraps a base network (1 Peer Org, 3 Orderers).
#   2. Dynamically adds 'peer2' to the channel.
#   3. Dynamically adds 'peer3' to the channel.
#   4. Finalizes chaincode endorsement across all 3 organizations.
#   Note: Network remains UP at the end of execution.
# ============================================================================

export ORG_CONFIG_FILE="NONE"

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

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer3.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer3.yaml" --hard

sudo rm -rf "${NETWORK_ORG_PATH}" "${NETWORK_IDS_PATH}" "${NETWORK_CHN_PATH}"
mkdir -p "${NETWORK_ORG_PATH}" "${NETWORK_IDS_PATH}" "${NETWORK_CHN_PATH}"

# ----------------------------------------------------------------------------
# PHASE 2: Core Infrastructure (Peer1 + Orderers)
# ----------------------------------------------------------------------------

# Generate crypto material for base members
for org in orderer1 orderer2 orderer3 peer1; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${org}.yaml" ./network-prepare.sh "${NETWORK_CRP_PATH}/${org}.yaml"
done

./network-init.sh # Generate genesis block

# Start containers
for org in orderer1 orderer2 orderer3 peer1; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${org}.yaml" ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-${org}.yaml"
done

# Join channel
for i in 1 2 3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer${i}.yaml" ./network-join-orderer.sh
done

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-peer.sh

# Initial Chaincode Deployment
./chaincode-install.sh
./chaincode-approve.sh
./chaincode-commit.sh

# ----------------------------------------------------------------------------
# PHASE 3: Onboard Organization 2
# ----------------------------------------------------------------------------

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer2.yaml" #
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer2.yaml" #

# Peer1 handles the join request
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/org2/configtx.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org2_update_in_envelope.pb"

# Peer2 joins channel
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-join-peer.sh
./network-set-anchor-peer.sh

./chaincode-install.sh # Install on the new peer (Peer2)

# ----------------------------------------------------------------------------
# PHASE 4: Onboard Organization 3
# ----------------------------------------------------------------------------

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer3.yaml"
./network-prepare.sh "${NETWORK_CRP_PATH}/peer3.yaml"
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer3.yaml"

# Peer1 (or Peer2) handles the join request for Peer3
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-join-request.sh "${NETWORK_CTX_PATH}/org3/configtx.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

# Existing members (Peer1 and Peer2) must approve the new configuration update
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer2.yaml"
./network-approve-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./network-commit-update.sh "${NETWORK_CHN_PATH}/org3_update_in_envelope.pb"

# Peer3 joins channel
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer3.yaml"
./network-join-peer.sh
./network-set-anchor-peer.sh

./chaincode-install.sh # Install on the new peer (Peer3)

# ----------------------------------------------------------------------------
# PHASE 5: Finalize Chaincode Endorsement Policy
# ----------------------------------------------------------------------------

# 1. Re-approve on ALL 3 organizations to update endorsement policy
for org in peer1 peer2 peer3; do
    export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${org}.yaml"
    ./chaincode-approve.sh
done

# 2. Commit the updated definition
export ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml"
./chaincode-commit.sh