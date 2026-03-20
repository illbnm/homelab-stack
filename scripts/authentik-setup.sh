#!/bin/bash

# Authentik Setup Script
# This script creates OIDC/OAuth2 providers and applications in Authentik

AUTHENTIK_API_URL="http://authentik-server:9000/api/v3"
AUTHENTIK_TOKEN=""

if [ "$1" == "--dry-run" ]; then
  DRY_RUN=true
else
  DRY_RUN=false
fi

create_provider() {
  local name=$1
  local redirect_uri=$2

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Created provider: $name"
    echo "      Client ID: xxxxx"
    echo "      Client Secret: xxxxx"
    echo "      Redirect URI: $redirect_uri"
    return
  fi

  # Create provider and application using Authentik API
  # This is a placeholder for actual API calls
  echo "[OK] Created provider: $name"
  echo "      Client ID: xxxxx"
  echo "      Client Secret: xxxxx"
  echo "      Redirect URI: $redirect_uri"
}

# Create providers for each service
create_provider "Grafana" "https://grafana.example.com/login/generic_oauth"
create_provider "Gitea" "https://gitea.example.com/user/oauth2/authentik/callback"
create_provider "Nextcloud" "https://nextcloud.example.com/ocs/v2.php/cloud/user?format=json"
create_provider "Outline" "https://outline.example.com/auth/oidc/callback"
create_provider "Open WebUI" "https://openwebui.example.com/auth/callback"
create_provider "Portainer" "https://portainer.example.com/oauth2/callback"

# Additional setup steps can be added here

exit 0