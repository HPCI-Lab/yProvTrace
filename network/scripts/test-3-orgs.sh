#!/bin/bash

# ============================================================================
# Test Description:
# This script sets up a Hyperledger Fabric network with:
#   - Three peer organizations (peer1, peer2, peer3)
#   - Three orderer organizations (orderer1, orderer2, orderer3)
# ============================================================================

source common.sh

# ---- For test only (Clean up existing containers) ----
for entity in orderer1 orderer2 orderer3 peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${entity}.yaml" \
        ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-${entity}.yaml" --hard
done

# Clean up directories
sudo rm -rf ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_IDS_PATH} ${NETWORK_CHN_PATH}

# -----------------------

# 1. Setup the crypto material
for entity in orderer1 orderer2 orderer3 peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${entity}.yaml" \
        ./network-prepare.sh "${NETWORK_CRP_PATH}/${entity}.yaml"
done

# 2. Initialize network (Done once after all crypto is ready)
./network-init.sh

# 3. Docker setup - Start all containers
for entity in orderer1 orderer2 orderer3 peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${entity}.yaml" \
        ./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-${entity}.yaml"
done

# 4. Channel setup - Orderers join
for ord in orderer1 orderer2 orderer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${ord}.yaml" \
        ./network-join-orderer.sh
done

# 5. Channel setup - Organizations join
for peer in peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${peer}.yaml" \
        ./network-join-peer.sh
done

# 6. Install the chaincode on all peers
for peer in peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${peer}.yaml" \
        ./chaincode-install.sh
done

# 7. Approve the chaincode for each organization
for peer in peer1 peer2 peer3; do
    ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/${peer}.yaml" \
        ./chaincode-approve.sh
done

# 8. Commit the chaincode definition (Only needs to be done by one org)
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./chaincode-commit.sh

# 9. Final Test: Invoke and Query from the last peer to ensure sync
sleep 5
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./chaincode-invoke.sh
sleep 5
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/peer1.yaml" \
    ./chaincode-query.sh