#!/bin/bash

# Authentik Setup Script
# This script sets up Authentik providers and applications automatically.

# Variables
AUTHENTIK_API_URL="http://authentik-server:8000/api/v3"
AUTHENTIK_TOKEN=""
DRY_RUN=false

# Check for dry-run flag
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
fi

# Function to create provider and application
create_provider_and_app() {
    local name=$1
    local redirect_uri=$2
    local client_id
    local client_secret

    # Create provider
    if [ "$DRY_RUN" = false ]; then
        response=$(curl -s -X POST -H "Authorization: Bearer $AUTHENTIK_TOKEN" -H "Content-Type: application/json" -d '{"name": "'"$name"'", "authorization_flow": "default-authentication-flow", "property_mappings": ["default-property-mapping"]}' $AUTHENTIK_API_URL/providers/oauth2/)
        client_id=$(echo $response | jq -r '.client_id')
        client_secret=$(echo $response | jq -r '.client_secret')
    else
        client_id="dry-run-client-id"
        client_secret="dry-run-client-secret"
    fi

    # Create application
    if [ "$DRY_RUN" = false ]; then
        curl -s -X POST -H "Authorization: Bearer $AUTHENTIK_TOKEN" -H "Content-Type: application/json" -d '{"name": "'"$name"'", "slug": "'"$name"'", "provider": "'"$client_id"'", "meta_launch_url": "'"$redirect_uri"'"}' $AUTHENTIK_API_URL/applications/
    fi

    echo "[OK] Created provider: $name"
    echo "     Client ID: $client_id"
    echo "     Client Secret: $client_secret"
    echo "     Redirect URI: $redirect_uri"
}

# Main script execution
if [ "$DRY_RUN" = false ]; then
    echo "Fetching Authentik token..."
    AUTHENTIK_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" -d '{"identifier": "'"$AUTHENTIK_BOOTSTRAP_EMAIL"'", "password": "'"$AUTHENTIK_BOOTSTRAP_PASSWORD"'"}' $AUTHENTIK_API_URL/core/users/me/token/ | jq -r '.key')
    if [ -z "$AUTHENTIK_TOKEN" ]; then
        echo "Failed to fetch Authentik token. Please check your credentials."
        exit 1
    fi
fi

# Create providers and applications
create_provider_and_app "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider_and_app "Gitea" "https://gitea.example.com/user/oauth2/callback"
create_provider_and_app "Nextcloud" "https://nextcloud.example.com/nextcloud/index.php/apps/oauth2callback"
create_provider_and_app "Outline" "https://outline.example.com/auth/oidc/callback"
create_provider_and_app "Open WebUI" "https://openwebui.example.com/auth/callback"
create_provider_and_app "Portainer" "https://portainer.example.com/oauth2/callback"

echo "Setup complete."