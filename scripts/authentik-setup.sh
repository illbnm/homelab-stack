#!/bin/bash

# Authentik Setup Script
# This script creates OIDC/OAuth2 providers and applications in Authentik

AUTHENTIK_API_URL="http://authentik-server:9000/api/v3"
AUTHENTIK_TOKEN=""

create_provider() {
    local name=$1
    local redirect_uri=$2

    echo "[INFO] Creating provider: $name"
    response=$(curl -s -X POST "$AUTHENTIK_API_URL/providers/oidc/" \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\", \"client_type\": \"confidential\", \"redirect_uris\": [\"$redirect_uri\"]}")

    if [[ $response == *"non_field_errors"* ]]; then
        echo "[ERROR] Failed to create provider: $name"
        echo "$response"
        exit 1
    fi

    client_id=$(echo "$response" | jq -r '.client_id')
    client_secret=$(echo "$response" | jq -r '.client_secret')

    echo "[OK] Created provider: $name"
    echo "     Client ID: $client_id"
    echo "     Client Secret: $client_secret"
    echo "     Redirect URI: $redirect_uri"
}

if [[ "$1" == "--dry-run" ]]; then
    echo "[DRY-RUN] Authentik setup script"
    echo "Would create providers for: Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer"
    exit 0
fi

echo "[INFO] Starting Authentik setup"

# Fetch Authentik token (assuming you have a way to get this token)
# AUTHENTIK_TOKEN=$(curl -s -X POST "$AUTHENTIK_API_URL/token/" -d "username=admin&password=$AUTHENTIK_BOOTSTRAP_PASSWORD" | jq -r '.access')

create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth2/authentik/callback"
create_provider "Nextcloud" "https://nextcloud.example.com/ocs/v2.php/cloud/user_oidc/callback"
create_provider "Outline" "https://outline.example.com/auth/oidc/callback"
create_provider "Open WebUI" "https://openwebui.example.com/auth/oidc/callback"
create_provider "Portainer" "https://portainer.example.com/callback"

echo "[INFO] Authentik setup complete"