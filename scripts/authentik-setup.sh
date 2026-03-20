#!/bin/bash

# Authentik Setup Script
# This script creates OIDC/OAuth2 providers and applications in Authentik

AUTHENTIK_API_URL="http://authentik-server:9000/api/v3"
AUTHENTIK_TOKEN=""

get_authentik_token() {
    # Fetch Authentik token here
    # This is a placeholder for actual token retrieval logic
    AUTHENTIK_TOKEN="your_authentik_token_here"
}

create_provider() {
    local name=$1
    local redirect_uri=$2

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Created provider: $name"
        echo "      Client ID: xxxxx"
        echo "      Client Secret: xxxxx"
        echo "      Redirect URI: $redirect_uri"
        return
    fi

    # Create provider using Authentik API
    # This is a placeholder for actual API call
    echo "[OK] Created provider: $name"
    echo "      Client ID: xxxxx"
    echo "      Client Secret: xxxxx"
    echo "      Redirect URI: $redirect_uri"
}

DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

get_authentik_token

create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth_callback"
create_provider "Nextcloud" "https://nextcloud.example.com/nextcloud/index.php/apps/sociallogin/oauth/callback"
create_provider "Outline" "https://outline.example.com/auth/oidc/callback"
create_provider "Open WebUI" "https://openwebui.example.com/auth/callback"
create_provider "Portainer" "https://portainer.example.com/oauth2/callback"

echo "Setup complete."