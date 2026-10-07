#!/bin/bash

# Fabric CA utilities for the currently selected organization. Every
# organization owns an independent CA. The same CA issues enrollment and TLS
# certificates using separate enrollment profiles backed by one root.

source common.sh

set_ca_env() {
    local org_dir
    org_dir=$(get_org_dir)

    export ORG_CA_HOME="${ORG_CA_HOME:-${NETWORK_CA_PATH}/${ORG_TYPE}Organizations/${ORG_DOMAIN}}"
    export ORG_CA_CERT_FILE="${ORG_CA_CERT_FILE:-${ORG_CA_HOME}/ca-cert.pem}"
    export ORG_CA_ADMIN_USER="${ORG_CA_ADMIN_USER:-ca-admin}"
    export ORG_CA_ADMIN_MSP="${ORG_CA_ADMIN_MSP:-${ORG_CA_HOME}/clients/${ORG_CA_ADMIN_USER}/msp}"
    export ORG_CA_TLS_CERT="${ORG_CA_TLS_CERT:-${ORG_CA_CERT_FILE}}"
    export ORG_CA_COMPOSE_FILE="${NETWORK_CMP_PATH}/docker-compose-ca.yaml"
    export ORG_ADMIN_ID="${ORG_ADMIN_ID:-Admin}"
    export ORG_ADMIN_MSP="${ORG_ADMIN_MSP:-${org_dir}/users/Admin@${ORG_DOMAIN}/msp}"
}

require_ca_admin_password() {
    if [[ -z "${ORG_CA_ADMIN_PASSWORD}" ]]; then
        log_error "ORG_CA_ADMIN_PASSWORD must be set in the environment."
        exit 1
    fi
}

require_ca_client() {
    if ! command -v fabric-ca-client >/dev/null 2>&1; then
        log_error "fabric-ca-client is not installed. Run install-requirements.sh."
        exit 1
    fi
}

require_running_ca() {
    set_ca_env
    if [[ ! -f "${ORG_CA_CERT_FILE}" ]]; then
        log_error "CA root certificate not found: ${ORG_CA_CERT_FILE}. Start ca-up.sh first."
        exit 1
    fi
}

ca_client() {
    require_ca_client
    fabric-ca-client "$@" \
        --url "${ORG_CA_URL}" \
        --caname "${ORG_CA_NAME}" \
        --tls.certfiles "${ORG_CA_TLS_CERT}"
}

enroll_ca_admin() {
    require_ca_client
    require_running_ca
    require_ca_admin_password

    if [[ -d "${ORG_CA_ADMIN_MSP}/signcerts" ]]; then
        log_info "CA bootstrap administrator is already enrolled for ${ORG_DOMAIN}."
        return
    fi

    mkdir -p "$(dirname "${ORG_CA_ADMIN_MSP}")"
    fabric-ca-client enroll \
        --url "https://${ORG_CA_ADMIN_USER}:${ORG_CA_ADMIN_PASSWORD}@localhost:${ORG_CA_PORT}" \
        --caname "${ORG_CA_NAME}" \
        --mspdir "${ORG_CA_ADMIN_MSP}" \
        --tls.certfiles "${ORG_CA_TLS_CERT}"
}

require_enrolled_ca_admin() {
    set_ca_env
    require_ca_client
    require_running_ca
    if [[ ! -d "${ORG_CA_ADMIN_MSP}/signcerts" ]]; then
        log_error "CA administrator is not enrolled. Run ca-enroll-admin.sh first."
        exit 1
    fi
}

write_node_ou_config() {
    local msp_dir=$1
    mkdir -p "${msp_dir}"
    sed -e "s|\${CA_CERT}|cacerts/ca.${ORG_DOMAIN}-cert.pem|g" \
        "${NETWORK_TMP_PATH}/msp-config-template.yaml" > "${msp_dir}/config.yaml"
}

normalize_enrollment_msp() {
    local msp_dir=$1
    mkdir -p "${msp_dir}/cacerts"
    cp "${ORG_CA_CERT_FILE}" "${msp_dir}/cacerts/ca.${ORG_DOMAIN}-cert.pem"
    write_node_ou_config "${msp_dir}"
}

register_identity() {
    local enrollment_id=$1
    local enrollment_secret=$2
    local identity_type=${3:-client}
    local affiliation=${4:-}
    local attributes=${5:-}

    case "${identity_type}" in
        client|admin|peer|orderer) ;;
        *) log_error "Identity type must be client, admin, peer, or orderer."; exit 1 ;;
    esac

    local args=(register --id.name "${enrollment_id}" --id.secret "${enrollment_secret}" --id.type "${identity_type}" --mspdir "${ORG_CA_ADMIN_MSP}")
    [[ -n "${affiliation}" ]] && args+=(--id.affiliation "${affiliation}")
    [[ -n "${attributes}" ]] && args+=(--id.attrs "${attributes}")
    ca_client "${args[@]}"
}

enroll_identity() {
    local enrollment_id=$1
    local enrollment_secret=$2
    local output_dir=${3:-"$(get_org_dir)/users/${enrollment_id}@${ORG_DOMAIN}/msp"}

    if [[ -e "${output_dir}" ]]; then
        log_error "Identity MSP already exists: ${output_dir}. Use ca-reenroll-user.sh to renew it."
        exit 1
    fi

    mkdir -p "$(dirname "${output_dir}")"
    fabric-ca-client enroll \
        --url "https://${enrollment_id}:${enrollment_secret}@localhost:${ORG_CA_PORT}" \
        --caname "${ORG_CA_NAME}" \
        --mspdir "${output_dir}" \
        --tls.certfiles "${ORG_CA_TLS_CERT}"
    normalize_enrollment_msp "${output_dir}"
    log_success "Identity '${enrollment_id}' enrolled at ${output_dir}"
}

enroll_tls_identity() {
    local enrollment_id=$1
    local enrollment_secret=$2
    local hostname=$3
    local output_dir=$4
    local temporary_msp="${ORG_CA_HOME}/tmp/${enrollment_id}-tls-msp"

    if [[ -e "${output_dir}" ]]; then
        log_error "TLS directory already exists: ${output_dir}"
        exit 1
    fi

    mkdir -p "${output_dir}" "$(dirname "${temporary_msp}")"
    fabric-ca-client enroll \
        --url "https://${enrollment_id}:${enrollment_secret}@localhost:${ORG_CA_PORT}" \
        --caname "${ORG_CA_NAME}" \
        --enrollment.profile tls \
        --csr.hosts "${hostname},localhost" \
        --mspdir "${temporary_msp}" \
        --tls.certfiles "${ORG_CA_TLS_CERT}"

    cp "${temporary_msp}/signcerts/cert.pem" "${output_dir}/server.crt"
    cp "${temporary_msp}/keystore/"* "${output_dir}/server.key"
    cp "${ORG_CA_CERT_FILE}" "${output_dir}/ca.crt"
    rm -rf "${temporary_msp}"
}

build_organization_msp() {
    local org_msp="$(get_org_dir)/msp"
    local public_msp="$(get_identity_dir)/msp"

    mkdir -p "${org_msp}/cacerts" "${org_msp}/tlscacerts"
    cp "${ORG_CA_CERT_FILE}" "${org_msp}/cacerts/ca.${ORG_DOMAIN}-cert.pem"
    cp "${ORG_CA_CERT_FILE}" "${org_msp}/tlscacerts/tlsca.${ORG_DOMAIN}-cert.pem"
    write_node_ou_config "${org_msp}"

    mkdir -p "$(get_identity_dir)"
    cp -rf "${org_msp}" "${public_msp}"
}

provision_organization() {
    local org_dir
    local node_id="${ORG_HOSTNAME}"
    local node_hostname="${ORG_HOSTNAME}.${ORG_DOMAIN}"
    local node_secret="${ORG_NODE_ENROLLMENT_SECRET:-$(openssl rand -hex 24)}"
    local admin_secret="${ORG_ADMIN_ENROLLMENT_SECRET:-$(openssl rand -hex 24)}"
    local node_dir
    org_dir=$(get_org_dir)

    if [[ "${ORG_TYPE}" == "peer" ]]; then
        node_dir="${org_dir}/peers/${node_hostname}"
    else
        node_dir="${org_dir}/orderers/${node_hostname}"
    fi

    if [[ -d "${node_dir}/msp" && -d "${node_dir}/tls" && -d "${ORG_ADMIN_MSP}/signcerts" ]]; then
        log_info "Organization ${ORG_DOMAIN} is already provisioned; keeping its existing credentials."
        return
    fi

    if [[ -e "${node_dir}" || -e "${ORG_ADMIN_MSP}" ]]; then
        log_error "Partial organization credentials exist under ${org_dir}; refusing to overwrite them."
        exit 1
    fi

    require_enrolled_ca_admin
    build_organization_msp
    register_identity "${node_id}" "${node_secret}" "${ORG_TYPE}"
    enroll_identity "${node_id}" "${node_secret}" "${node_dir}/msp"
    enroll_tls_identity "${node_id}" "${node_secret}" "${node_hostname}" "${node_dir}/tls"
    register_identity "${ORG_ADMIN_ID}" "${admin_secret}" admin
    enroll_identity "${ORG_ADMIN_ID}" "${admin_secret}" "${ORG_ADMIN_MSP}"

    if [[ "${ORG_TYPE}" == "orderer" ]]; then
        mkdir -p "$(get_identity_dir)/tls"
        cp "${node_dir}/tls/server.crt" "$(get_identity_dir)/tls/server.crt"
    fi
}

stage_crl() {
    local generated_crl="${ORG_CA_ADMIN_MSP}/crls/crl.pem"
    local org_dir
    local identity_dir
    org_dir=$(get_org_dir)
    identity_dir=$(get_identity_dir)

    if [[ ! -f "${generated_crl}" ]]; then
        log_error "The CA did not generate the expected CRL: ${generated_crl}"
        exit 1
    fi

    mkdir -p "${org_dir}/msp/crls" "${identity_dir}/msp/crls"
    cp "${generated_crl}" "${org_dir}/msp/crls/crl.pem"
    cp "${generated_crl}" "${identity_dir}/msp/crls/crl.pem"
    log_success "CRL staged in the local and shared MSP directories."
    log_info "WARNING: the channel MSP must still be updated with this CRL before peers enforce the revocation."
}

set_ca_env
