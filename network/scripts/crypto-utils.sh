#!/bin/bash

. set-env.sh

generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH} > /dev/null 2>&1
    echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"
}

generate_ccp() {

    local crypto_config_file=$1

    local org=$(yq -r '.PeerOrgs' ${crypto_config_file})

    if [ -z "$org" ] || [ "$org" == "null" ]; then
        echo "Skipping..."
        return
    fi

    local name=$(echo "$org" | jq -r 'to_entries[0] | .value | .Name')
    local domain=$(echo "$org" | jq -r 'to_entries[0] | .value | .Domain')
    local org_cert_path="${NETWORK_ORG_PATH}/peerOrganizations/${domain}/tlsca/tlsca.${domain}-cert.pem"

    set_peer ${domain} ${DEFAULT_PEER_ID}

    local org_ccp_file="${NETWORK_ORG_PATH}/peerOrganizations/${domain}/connection-${name,,}.json"

    sed -e "s|\${ORG_NAME}|$name|" \
        -e "s|\${MSPID}|$CORE_PEER_LOCALMSPID|" \
        -e "s|\${PEER_HOSTNAME}|$PEER_HOSTNAME|" \
        -e "s|\${ENDPOINT}|$CORE_PEER_ADDRESS|" \
        -e "s|\${ORG_CERT_PATH}|$org_cert_path|" \
        ${NETWORK_TMP_PATH}/ccp-template.json > $org_ccp_file

    echo "Organization-level Common Connection Profile generated at $org_ccp_file"
}

delete_crypto() {

    local ORG_DOMAIN=$1

    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN,,}"
    echo "Cryptographic material for organization ${ORG_DOMAIN} deleted successfully."
}


