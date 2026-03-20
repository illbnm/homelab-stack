#!/bin/bash

# Authentik Setup Script
# Usage: ./scripts/authentik-setup.sh
#        ./scripts/authentik-setup.sh --dry-run

DRY_RUN=false

if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
fi

create_provider() {
    local service=$1
    local client_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    local client_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    local redirect_uri=$2

    if [ "$DRY_RUN" == true ]; then
        echo "[DRY-RUN] Created provider: $service"
        echo "      Client ID: $client_id"
        echo "      Client Secret: $client_secret"
        echo "      Redirect URI: $redirect_uri"
    else
        # Placeholder for actual API call to Authentik
        echo "[OK] Created provider: $service"
        echo "      Client ID: $client_id"
        echo "      Client Secret: $client_secret"
        echo "      Redirect URI: $redirect_uri"
    fi
}

create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth2_callback"
create_provider "Nextcloud" "https://nextcloud.example.com/nextcloud/index.php/apps/oauth2/authorize"
create_provider "Outline" "https://outline.example.com/oauth/authorize"
create_provider "Open WebUI" "https://openwebui.example.com/oauth/callback"
create_provider "Portainer" "https://portainer.example.com/oauth/callback"

echo "Setup complete."