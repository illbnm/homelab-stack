#!/bin/bash

# Authentik Setup Script
# This script sets up Authentik providers and applications automatically.

AUTHENTIK_API_URL="http://authentik-server:8000/api/v3"
AUTHENTIK_TOKEN=""

get_authentik_token() {
    local response=$(curl -s -X POST "${AUTHENTIK_API_URL}/core/tokens/" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"setup-script\", \"expiry_date\": null, \"scope\": [\"authentik.providers.create\", \"authentik.applications.create\"]}")
    AUTHENTIK_TOKEN=$(echo $response | jq -r '.token')
}

create_provider() {
    local name=$1
    local redirect_uri=$2
    local response=$(curl -s -X POST "${AUTHENTIK_API_URL}/providers/oidc/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        -d "{\"name\": \"${name}\", \"authorization_flow\": \"default-authentication-flow\", \"redirect_uris\": [\"${redirect_uri}\"], \"client_type\": \"confidential\", \"sub_mode\": \"hashed_user_id\"}")
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
    curl -s -X POST "${AUTHENTIK_API_URL}/applications/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        -d "{\"name\": \"${name}\", \"slug\": \"${name// /-}\", \"provider\": \"${provider}\", \"meta_launch_url\": \"https://${name}.example.com\"}"
}

if [ "$1" == "--dry-run" ]; then
    echo "Dry run mode. No changes will be made."
    exit 0
fi

get_authentik_token

create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth2/callback"
create_provider "Nextcloud" "https://nextcloud.example.com/nextcloud/index.php/apps/oauth2/authorize"
create_provider "Outline" "https://outline.example.com/api/oauth/authorize"
create_provider "Open WebUI" "https://openwebui.example.com/auth/callback"
create_provider "Portainer" "https://portainer.example.com/oauth2/callback"

create_application "Grafana" "grafana"
create_application "Gitea" "gitea"
create_application "Nextcloud" "nextcloud"
create_application "Outline" "outline"
create_application "Open WebUI" "open-webui"
create_application "Portainer" "portainer"

echo "Setup complete."