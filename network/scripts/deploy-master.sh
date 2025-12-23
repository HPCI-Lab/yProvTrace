#!/bin/bash

# ============================================================================
# yProvTrace: Deploy Master Script
# ============================================================================
# Description:
#   This script automates a full lifecycle test of the yProvTrace network:
#   1. Bootstraps a base network (1 Peer Org, 3 Orderer Orgs).
#   2. Deploys and verifies the 'cc-test' chaincode.
# ============================================================================

source common.sh

# ! You NEED to pick the right organization configuration file before running

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

./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" --hard

# Wipe existing ledger data, channel artifacts, and identity certificates

sudo -u gsuser rm -rf /data_hlf1/fabric/orderer_hpcilab_ord1_data
sudo -u gsuser rm -rf /data_hlf1/fabric/orderer_hpcilab_ord2_data
sudo -u gsuser rm -rf /data_hlf1/fabric/orderer_hpcilab_ord3_data
sudo -u gsuser rm -rf /data_hlf1/fabric/peer0_${ORG_DOMAIN}_data

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

./network-prepare.sh "${NETWORK_CRP_PATH}/peer1.yaml"

# Ensure read permissions for all generated crypto material
chmod -R +r ../organizations/ordererOrganizations
chmod -R +r ../organizations/peerOrganizations

# Leader Org generates the Genesis Block for the system/application channel
./network-init.sh

sudo -u gsuser mkdir /data_hlf1/fabric/orderer_hpcilab_ord1_data
sudo -u gsuser mkdir /data_hlf1/fabric/orderer_hpcilab_ord2_data
sudo -u gsuser mkdir /data_hlf1/fabric/orderer_hpcilab_ord3_data
sudo -u gsuser mkdir /data_hlf1/fabric/peer1_${ORG_DOMAIN}_data

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

./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" # Start the organization 1

# All orderers join the channel
ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./network-join-orderer.sh

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./network-join-orderer.sh

# Peer organization joins the channel
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
# PHASE 5 (Test only): Final Teardown
# ----------------------------------------------------------------------------

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer1.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer1.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer2.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer2.yaml" --hard

ORG_CONFIG_FILE="${NETWORK_CRP_PATH}/orderer3.yaml" \
    ./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-orderer3.yaml" --hard

./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-peer1.yaml" --hard