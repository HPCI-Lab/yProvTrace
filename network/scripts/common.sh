#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export NETWORK_ROOT="${PROJECT_ROOT}/network"
export CHAINCODE_ROOT="${PROJECT_ROOT}/chaincode"

source logging.sh

# ============================================================================
# Configuration Management
# ============================================================================

# Load network configuration from a given YAML file
load_network_config() {
    local config_file="${NETWORK_ROOT}/config/network.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Network configuration file not found: $config_file"
        exit 1
    fi

    log_info "Loading network configuration from $config_file"

    # General network settings
    export NETWORK_NAME=$(yq -r '.network.name' "$config_file")
    export CHANNEL_NAME=$(yq -r '.network.channel' "$config_file")
    export CHAINCODE_NAME=$(yq -r '.network.chaincode.name' "$config_file")
    export CHAINCODE_LANGUAGE=$(yq -r '.network.chaincode.language' "$config_file")
    export CHAINCODE_VERSION=$(yq -r '.network.chaincode.version' "$config_file")
    export CHAINCODE_SRC_PATH="${CHAINCODE_ROOT}/${CHAINCODE_NAME}"

    # Paths
    export NETWORK_BIN_PATH=${NETWORK_ROOT}$(yq -r '.paths.bin' "$config_file")
    export NETWORK_CHN_PATH=${NETWORK_ROOT}$(yq -r '.paths.channel' "$config_file")
    export NETWORK_CMP_PATH=${NETWORK_ROOT}$(yq -r '.paths.compose' "$config_file")
    export NETWORK_CFG_PATH=${NETWORK_ROOT}$(yq -r '.paths.config' "$config_file")
    export NETWORK_CTX_PATH=${NETWORK_ROOT}$(yq -r '.paths.configtx' "$config_file")
    export NETWORK_IDS_PATH=${NETWORK_ROOT}$(yq -r '.paths.identities' "$config_file")
    export NETWORK_ORG_PATH=${NETWORK_ROOT}$(yq -r '.paths.organizations' "$config_file")
    export NETWORK_PKG_PATH=${NETWORK_ROOT}$(yq -r '.paths.packages' "$config_file")
    export NETWORK_TMP_PATH=${NETWORK_ROOT}$(yq -r '.paths.templates' "$config_file")
    export NETWORK_CRP_PATH=${NETWORK_CFG_PATH}$(yq -r '.paths.crypto' "$config_file")

    # Export fabric-specific variables
    export PATH="${PATH}:${NETWORK_BIN_PATH}"
    export FABRIC_CFG_PATH="${NETWORK_CFG_PATH}/fabric"
    export FABRIC_VERSION=$(yq -r '.fabric.version' "$config_file")
    
    # Export docker-specific variables
    export COMPOSE_BAKE=true
    export DOCKER_PROJECT_NAME=$(yq -r '.docker.project' "$config_file")
    
    log_success "Network configuration loaded successfully"
}

# Load organization configuration from a given YAML file
load_organization_config() {
    local org_config_file=$1

    if [[ ! -f "$org_config_file" ]]; then
        log_error "Organization configuration file not found: $org_config_file"
        exit 1
    fi

    local org=$(yq -r '.PeerOrgs' ${org_config_file})
    local ord=$(yq -r '.OrdererOrgs' ${org_config_file})

    if [[ "$org" != "null" ]]; then
        data=$(echo "$org" | jq -r 'to_entries[0] | .value')
        specs=$(echo "$data" | jq -r '.Template')
        
        export ORG_TYPE="peer"
        export ORG_HOSTNAME="peer0"
        export ORG_DEFAULT_ORDERER_DOMAIN=$(echo "$data" | jq -r '.DefaultOrdererDomain')
    elif [[ "$ord" != "null" ]]; then
        data=$(echo "$ord" | jq -r 'to_entries[0] | .value')
        specs=$(echo "$data" | jq -r '.Specs[0]')
        
        export ORG_TYPE="orderer"
        export ORG_HOSTNAME=$(echo "$specs" | yq -r '.Hostname')
        export ORG_ADMIN_PORT=$(echo "$specs" | yq -r '.Ports.AdminPort')
    else
        log_error "No valid organization configuration found in: $org_config_file"
        exit 1
    fi
    
    # Parse organization configuration
    export ORG_NAME=$(echo "$data" | jq -r '.Name')
    export ORG_DOMAIN=$(echo "$data" | jq -r '.Domain')
    export ORG_MSP_ID=$(echo "$data" | jq -r '.MSPId')
    export ORG_ENDPOINT=$(echo "$specs" | yq -r '.DefaultEndpoint')
    export ORG_LISTEN_PORT=$(echo "$specs" | yq -r '.Ports.ListenPort')
    export ORG_OPERATIONS_PORT=$(echo "$specs" | yq -r '.Ports.OperationsPort')
    export LAST_ORG_CONFIG_FILE="${org_config_file}"
    
    log_debug "Organization configuration loaded: ${ORG_NAME}"
}

select_organization() {

    local org_files=$(find "${NETWORK_CRP_PATH}" -maxdepth 1 -type f -name "*.yaml" -or -name "*.yml" | sort)
    local file_count=$(echo "$org_files" | grep -c .)

    local selected=""
    if [ "$file_count" -eq 0 ]; then
        log_error "No organization configuration files found in ${NETWORK_CRP_PATH}"
        exit 1
    elif [ "$file_count" -eq 1 ]; then
        selected="$org_files"
        log_info "Auto-selected (only option): $selected"
    else
        
        FZF_OPTS=(
            --prompt="🏢 Organization › "
            --height=40%
            --border=rounded
            --border-label=" Select Configuration "
            --cycle
            --select-1
            --exit-0
            --pointer="▶"
            --header="↑/↓: navigate | Enter: select | Esc: cancel"
            --preview='cat {}'
            --preview-window=right:50%:wrap
            --color='border:#89b4fa,prompt:#f38ba8'
        )
        
        # If ORG_CONFIG_FILE is not a file, then skip the selection
        if [ ! -f "$ORG_CONFIG_FILE" ]; then
            log_info "Configuration file not required"
            return
        fi

        # Using selected option if provided
        [ -n "$ORG_CONFIG_FILE" ] && FZF_OPTS+=(--query="$ORG_CONFIG_FILE")

        selected=$(printf "%s\n" "$org_files" | fzf "${FZF_OPTS[@]}")
        
        if [ -z "$selected" ]; then
            log_error "No organization selected"
            exit 1
        fi
        
        log_info "Selected organization configuration: $selected"
    fi

    if [ "$selected" == "$LAST_ORG_CONFIG_FILE" ]; then
        log_debug "Organization already selected: ${ORG_DOMAIN}, skipping reload..."
        return
    fi

    load_organization_config "${selected}"
}

# ============================================================================
# Path Management
# ============================================================================

# Get organization directory
get_org_dir() {
    local domain="${1:-${ORG_DOMAIN}}"
    local org_type="${2:-${ORG_TYPE}}"
    
    if [[ "$org_type" == "orderer" ]]; then
        echo "${NETWORK_ORG_PATH}/ordererOrganizations/${domain}"
    else
        echo "${NETWORK_ORG_PATH}/peerOrganizations/${domain}"
    fi
}

# Get identity directory
get_identity_dir() {
    local domain="${1:-${ORG_DOMAIN}}"
    local org_type="${2:-${ORG_TYPE}}"
    
    if [[ "$org_type" == "orderer" ]]; then
        echo "${NETWORK_IDS_PATH}/ordererOrganizations/${domain}"
    else
        echo "${NETWORK_IDS_PATH}/peerOrganizations/${domain}"
    fi
}

# Get genesis block path
get_genesis_block() {
    echo "${NETWORK_CHN_PATH}/genesis.block"
}

# Get chaincode package path
get_chaincode_package() {
    local cc_name="${1:-${CHAINCODE_NAME}}"
    local cc_version="${2:-${CHAINCODE_VERSION}}"
    echo "${NETWORK_PKG_PATH}/${cc_name}_${cc_version}.tar.gz"
}

# ============================================================================
# Peer Environment Setup
# ============================================================================

# Export environment variables for a specific peer
set_peer_env() {

    local identity_dir=$(get_identity_dir)
    local org_dir=$(get_org_dir)
    
    # Export peer environment variables
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="${ORG_MSP_ID}"
    export CORE_PEER_ADDRESS="${ORG_ENDPOINT}:${ORG_LISTEN_PORT}"

    # * This is public available info, so it should be retrieved from identities folder
    export CORE_PEER_TLS_ROOTCERT_FILE="${identity_dir}/msp/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem"

    # * This is private info, so it should be retrieved from organizations folder
    export CORE_PEER_MSPCONFIGPATH="${org_dir}/users/Admin@${ORG_DOMAIN}/msp"
    
    # Additional peer configuration
    export PEER_HOSTNAME="${ORG_HOSTNAME}.${ORG_DOMAIN}"
    export PEER_DOMAIN="${ORG_DOMAIN}"
    
    log_debug "Peer environment set: ${CORE_PEER_ADDRESS}"
}

# ============================================================================
# Orderer Environment Setup
# ============================================================================

get_default_orderer() {
    local orderer_domain="${1:-${ORG_DEFAULT_ORDERER_DOMAIN}}"
    local identity_dir=$(get_identity_dir "${orderer_domain}" "orderer")
    local json_file="${identity_dir}/endpoints.json"

    if [ ! -f "${json_file}" ]; then
        log_error "Orderer endpoints file not found: ${json_file}"
        exit 1
    fi

    local orderer_hostname=$(jq -r '.service.hostname' "${json_file}").${orderer_domain}
    local orderer_address=$(jq -r '.service.address' "${json_file}")
    local tls_ca_cert="${identity_dir}/msp/tlscacerts/tlsca.${orderer_domain}-cert.pem"

    export ORDERER_HOSTNAME="${orderer_hostname}"
    export ORDERER_ADDRESS="${orderer_address}"
    export ORDERER_TLS_CA="${tls_ca_cert}"
}

# Export environment variables for a specific orderer
set_orderer_env() {
    
    local identity_dir=$(get_identity_dir)
    local org_dir=$(get_org_dir)
    
    # Export orderer environment variables
    export ORDERER_DOMAIN="${ORG_DOMAIN}"
    export ORDERER_HOSTNAME="${ORG_HOSTNAME}.${ORG_DOMAIN}"
    export ORDERER_ADDRESS="${ORG_ENDPOINT}:${ORG_LISTEN_PORT}"
    export ORDERER_ADMIN_ADDRESS="${ORG_ENDPOINT}:${ORG_ADMIN_PORT}"
    export ORDERER_TLS_CA="${identity_dir}/msp/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem"
    export ORDERER_TLS_SIGN_CERT="${identity_dir}/tls/server.crt"
    export ORDERER_TLS_PRIVATE_KEY="${org_dir}/orderers/${ORG_HOSTNAME}.${ORG_DOMAIN}/tls/server.key"
    
    log_debug "Orderer environment set: ${ORDERER_ADDRESS}"
}

# ============================================================================
# Execute always here
# ============================================================================
if [ -z "${NETWORK_CONFIG_LOADED}" ]; then
    load_network_config
    export NETWORK_CONFIG_LOADED=true
else
    log_debug "Network config already loaded, skipping..."
    
    # Only select the organization if it hasn't been selected yet
    if [ -z "${LAST_ORG_CONFIG_FILE}" ]; then
        select_organization
    fi
fi