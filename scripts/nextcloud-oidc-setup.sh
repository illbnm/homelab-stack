#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Setup Script
# Installs and configures nextcloud sociallogin app to integrate with Authentik OIDC
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DOMAIN="${DOMAIN:-example.com}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"

echo "Installing Nextcloud sociallogin app..."
docker exec -i --user www-data nextcloud php occ app:install sociallogin || true
docker exec -i --user www-data nextcloud php occ app:enable sociallogin || true

echo "Configuring Authentik OIDC provider in Nextcloud..."
# Set sociallogin config using occ config:app:set
docker exec -i --user www-data nextcloud php occ config:app:set sociallogin custom_providers \
  --value="{\"custom_oidc\":[{\"name\":\"Authentik\",\"title\":\"Authentik\",\"clientId\":\"${CLIENT_ID}\",\"clientSecret\":\"${CLIENT_SECRET}\",\"authorizeUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/authorize/\",\"tokenUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/token/\",\"userinfoUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/userinfo/\",\"scope\":\"openid profile email\",\"style\":\"default\",\"buttonText\":\"Log in with Authentik\"}]}"

echo "Nextcloud OIDC configuration complete!"
