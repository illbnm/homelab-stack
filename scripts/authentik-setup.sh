#!/bin/bash

# Authentik Setup Script
# This script sets up Authentik providers and applications automatically.

AUTHENTIK_API_URL="http://authentik-server:9000/api/v3"
AUTHENTIK_TOKEN=""

get_authentik_token() {
    local response=$(curl -s -X POST "${AUTHENTIK_API_URL}/core/tokens/" \
        -H "Content-Type: application/json" \
        -d "{\"identifier\": \"admin\", \"password\": \"${AUTHENTIK_BOOTSTRAP_PASSWORD}\"}")
    AUTHENTIK_TOKEN=$(echo $response | jq -r '.token')
}

create_provider() {
    local name=$1
    local redirect_uri=$2
    local response=$(curl -s -X POST "${AUTHENTIK_API_URL}/providers/oauth2/" \
        -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${name}\", \"client_type\": \"confidential\", \"redirect_uris\": [\"${redirect_uri}\"], \"sub_mode\": \"email\"}")
    local client_id=$(echo $response | jq -r '.client_id')
    local client_secret=$(echo $response | jq -r '.client_secret')
    echo "[OK] Created provider: ${name}"
    echo "     Client ID: ${client_id}"
    echo "     Client Secret: ${client_secret}"
    echo "     Redirect URI: ${redirect_uri}"
}

create_application() {
    local name=$1
    local provider=$2
    local response=$(curl -s -X POST "${AUTHENTIK_API_URL}/applications/" \
        -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${name}\", \"slug\": \"${name}\", \"provider\": \"${provider}\"}")
    echo "[OK] Created application: ${name}"
}

if [ "$1" == "--dry-run" ]; then
    echo "Dry run mode. No changes will be made."
    exit 0
fi

get_authentik_token

create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth2/authentik/callback"
create_provider "Nextcloud" "https://nextcloud.example.com/ocs/v2.php/apps/oauth2/api/v1/token"
create_provider "Outline" "https://outline.example.com/oauth/callback"
create_provider "Open WebUI" "https://openwebui.example.com/auth/callback"
create_provider "Portainer" "https://portainer.example.com/oauth/callback"

create_application "Grafana" "grafana"
create_application "Gitea" "gitea"
create_application "Nextcloud" "nextcloud"
create_application "Outline" "outline"
create_application "Open WebUI" "openwebui"
create_application "Portainer" "portainer"

echo "Setup complete."