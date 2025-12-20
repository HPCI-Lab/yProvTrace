#!/bin/bash

# ============================================================================
# yProvTrace: Common Configuration & Environment Management
# ============================================================================
# Description:
#   Core script providing centralized configuration management and environment
#   setup for the entire yProvTrace network. This script is sourced by all
#   other scripts to ensure consistent configuration and behavior.
#
# Key Responsibilities:
#   1. Load network-wide configuration from YAML files
#   2. Manage organization selection and configuration
#   3. Set up peer and orderer environments
#   4. Provide path management utilities
#   5. Export Fabric and Docker environment variables
#
# Configuration Files:
#   - network.yaml : Network-wide settings (channel, chaincode, paths)
#   - org/*.yaml   : Organization-specific configurations
#
# Functions:
#   - load_network_config()      : Load network.yaml settings
#   - load_organization_config() : Parse organization YAML
#   - select_organization()      : Interactive or explicit org selection
#   - get_org_dir()             : Organization directory path
#   - get_identity_dir()        : Identity/public cert directory
#   - get_genesis_block()       : Genesis block file path
#   - get_chaincode_package()   : Chaincode package path
#   - set_peer_env()            : Configure peer environment variables
#   - get_default_orderer()     : Retrieve default orderer info
#   - set_orderer_env()         : Configure orderer environment variables
#
# Auto-Execution:
#   - Loads network configuration on first source
#   - Selects organization if ORG_CONFIG_FILE is set
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export NETWORK_ROOT="${PROJECT_ROOT}/network"
export CHAINCODE_ROOT="${PROJECT_ROOT}/chaincode"

source logging.sh

# ============================================================================
# Configuration Management
# ============================================================================

# ----------------------------------------------------------------------------
# Load Network Configuration
# ----------------------------------------------------------------------------
# Description: Loads network-wide settings from network.yaml
# Purpose: Establishes global network parameters and paths
# Exports: All network configuration as environment variables
# Exit: 1 if configuration file not found
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Load Organization Configuration
# ----------------------------------------------------------------------------
# Description: Parses organization-specific YAML configuration
# Parameters:
#   $1 - Path to organization configuration file (YAML)
# Purpose: Extracts organization details (name, domain, MSP ID, endpoints)
# Exports: Organization-specific environment variables (ORG_*)
# Note: Handles both peer and orderer organization types
# Exit: 1 if configuration file not found or invalid
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Select Organization
# ----------------------------------------------------------------------------
# Description: Manages organization selection for script execution
# Modes:
#   1. Explicit: ORG_CONFIG_FILE is set → load that organization
#   2. Cached: Organization already loaded → skip selection
#   3. Interactive: No org selected → prompt user with fzf
# Special: ORG_CONFIG_FILE="NONE" skips organization selection
# Purpose: Ensures correct organization context before operations
# Exit: 1 if no organization selected or file not found
# ----------------------------------------------------------------------------
select_organization() {
    # If ORG_CONFIG_FILE is explicitly set and different from last, load it directly
    if [[ -n "${ORG_CONFIG_FILE}" && "${ORG_CONFIG_FILE}" != "${LAST_ORG_CONFIG_FILE}" ]]; then
        
        # Handle special case where user wants to skip org selection
        if [[ "${ORG_CONFIG_FILE}" == "NONE" ]]; then
            log_info "Organization selection skipped (ORG_CONFIG_FILE=NONE)"
            return
        fi
        
        # Validate the explicitly provided config file
        if [[ ! -f "${ORG_CONFIG_FILE}" ]]; then
            log_error "Explicitly specified organization config file not found: ${ORG_CONFIG_FILE}"
            exit 1
        fi
        
        log_info "Using explicitly specified organization: ${ORG_CONFIG_FILE}"
        load_organization_config "${ORG_CONFIG_FILE}"
        return
    fi

    # If organization is already loaded and ORG_CONFIG_FILE wasn't explicitly changed, skip
    if [[ -n "${LAST_ORG_CONFIG_FILE}" ]]; then
        log_debug "Organization already loaded: ${ORG_DOMAIN}, skipping selection..."
        return
    fi

    # Interactive selection when no organization is specified
    local org_files=$(find "${NETWORK_CRP_PATH}" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
    local file_count=$(echo "$org_files" | grep -c .)

    if [[ "$file_count" -eq 0 ]]; then
        log_error "No organization configuration files found in ${NETWORK_CRP_PATH}"
        exit 1
    elif [[ "$file_count" -eq 1 ]]; then
        local selected="$org_files"
        log_info "Auto-selected (only option): $selected"
        load_organization_config "${selected}"
    else
        local FZF_OPTS=(
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
        
        local selected=$(printf "%s\n" "$org_files" | fzf "${FZF_OPTS[@]}")
        
        if [[ -z "$selected" ]]; then
            log_error "No organization selected"
            exit 1
        fi
        
        log_info "Selected organization configuration: $selected"
        load_organization_config "${selected}"
    fi
}

# ============================================================================
# Path Management
# ============================================================================

# ----------------------------------------------------------------------------
# Get Organization Directory
# ----------------------------------------------------------------------------
# Description: Returns the organization's MSP directory path
# Parameters:
#   $1 - Organization domain (default: ORG_DOMAIN)
#   $2 - Organization type (default: ORG_TYPE)
# Returns: Absolute path to organization directory
# Note: Path differs for peer vs orderer organizations
# ----------------------------------------------------------------------------
get_org_dir() {
    local domain="${1:-${ORG_DOMAIN}}"
    local org_type="${2:-${ORG_TYPE}}"
    
    if [[ "$org_type" == "orderer" ]]; then
        echo "${NETWORK_ORG_PATH}/ordererOrganizations/${domain}"
    else
        echo "${NETWORK_ORG_PATH}/peerOrganizations/${domain}"
    fi
}

# ----------------------------------------------------------------------------
# Get Identity Directory
# ----------------------------------------------------------------------------
# Description: Returns the organization's public identity directory path
# Parameters:
#   $1 - Organization domain (default: ORG_DOMAIN)
#   $2 - Organization type (default: ORG_TYPE)
# Returns: Absolute path to identity directory
# Purpose: Stores public certificates and TLS certs shared across network
# ----------------------------------------------------------------------------
get_identity_dir() {
    local domain="${1:-${ORG_DOMAIN}}"
    local org_type="${2:-${ORG_TYPE}}"
    
    if [[ "$org_type" == "orderer" ]]; then
        echo "${NETWORK_IDS_PATH}/ordererOrganizations/${domain}"
    else
        echo "${NETWORK_IDS_PATH}/peerOrganizations/${domain}"
    fi
}

# ----------------------------------------------------------------------------
# Get Genesis Block Path
# ----------------------------------------------------------------------------
# Description: Returns the path to the channel genesis block
# Returns: Absolute path to genesis.block file
# Purpose: Genesis block is used by all members to join the channel
# ----------------------------------------------------------------------------
get_genesis_block() {
    echo "${NETWORK_CHN_PATH}/genesis.block"
}

# ----------------------------------------------------------------------------
# Get Chaincode Package Path
# ----------------------------------------------------------------------------
# Description: Returns the path to a chaincode package file
# Parameters:
#   $1 - Chaincode name (default: CHAINCODE_NAME)
#   $2 - Chaincode version (default: CHAINCODE_VERSION)
# Returns: Absolute path to .tar.gz package file
# Purpose: Standard naming convention for chaincode packages
# ----------------------------------------------------------------------------
get_chaincode_package() {
    local cc_name="${1:-${CHAINCODE_NAME}}"
    local cc_version="${2:-${CHAINCODE_VERSION}}"
    echo "${NETWORK_PKG_PATH}/${cc_name}_${cc_version}.tar.gz"
}

# ============================================================================
# Peer Environment Setup
# ============================================================================

# ----------------------------------------------------------------------------
# Set Peer Environment
# ----------------------------------------------------------------------------
# Description: Configures environment variables for peer operations
# Purpose: Prepares shell environment for peer CLI commands
# Exports:
#   - CORE_PEER_TLS_ENABLED        : Enable TLS
#   - CORE_PEER_LOCALMSPID         : Organization MSP ID
#   - CORE_PEER_ADDRESS            : Peer endpoint
#   - CORE_PEER_TLS_ROOTCERT_FILE  : TLS root certificate (public)
#   - CORE_PEER_MSPCONFIGPATH      : Admin MSP directory (private)
#   - PEER_HOSTNAME                : Peer fully qualified hostname
#   - PEER_DOMAIN                  : Organization domain
# Note: Uses public certs from identities folder for TLS
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Get Default Orderer
# ----------------------------------------------------------------------------
# Description: Retrieves default orderer information from endpoints.json
# Parameters:
#   $1 - Orderer domain (default: ORG_DEFAULT_ORDERER_DOMAIN)
# Purpose: Provides orderer connection details for channel operations
# Exports:
#   - ORDERER_HOSTNAME : Orderer fully qualified hostname
#   - ORDERER_ADDRESS  : Orderer endpoint with port
#   - ORDERER_TLS_CA   : Orderer TLS certificate path
# Exit: 1 if endpoints file not found
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Set Orderer Environment
# ----------------------------------------------------------------------------
# Description: Configures environment variables for orderer operations
# Purpose: Prepares shell environment for osnadmin and orderer CLI commands
# Exports:
#   - ORDERER_DOMAIN           : Orderer domain
#   - ORDERER_HOSTNAME         : Orderer fully qualified hostname
#   - ORDERER_ADDRESS          : Orderer service endpoint
#   - ORDERER_ADMIN_ADDRESS    : Orderer admin API endpoint
#   - ORDERER_TLS_CA           : TLS root certificate (public)
#   - ORDERER_TLS_SIGN_CERT    : TLS signing certificate (public)
#   - ORDERER_TLS_PRIVATE_KEY  : TLS private key (private)
# Note: Combines public and private paths for orderer operations
# ----------------------------------------------------------------------------
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
# Auto-Initialization (Executed on Script Source)
# ============================================================================

# Load network configuration once per shell session
# Execute always here
if [ -z "${NETWORK_CONFIG_LOADED}" ]; then
    load_network_config
    export NETWORK_CONFIG_LOADED=true
else
    log_debug "Network config already loaded, skipping..."
fi

# Always check if organization needs to be selected or reloaded
select_organization