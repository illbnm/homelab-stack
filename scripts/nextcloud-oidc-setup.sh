#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Setup Script
# Installs sociallogin Nextcloud app and configures custom OIDC with Authentik.
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env from root
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

DOMAIN="${DOMAIN:-example.com}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN}"

NEXTCLOUD_CONTAINER="nextcloud"

if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container is not running. Start the storage stack first!"
  exit 1
fi

log_step "Installing 'sociallogin' Nextcloud app..."
if docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:list | grep -q "sociallogin"; then
  log_info "Nextcloud app 'sociallogin' is already installed."
else
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install sociallogin
  log_info "Nextcloud app 'sociallogin' installed successfully."
fi

log_step "Configuring custom OIDC provider (Authentik) in Nextcloud..."
# Configure sociallogin Custom OIDC settings using Nextcloud OCC
# Read client ID and client secret from environment
CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log_warn "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET not set in .env."
  log_warn "Please run ./scripts/authentik-setup.sh first to generate credentials."
  exit 1
fi

# Authentik Custom OIDC configuration payload JSON
OIDC_CONFIG=$(jq -n \
  --arg id "$CLIENT_ID" \
  --arg secret "$CLIENT_SECRET" \
  --arg auth_url "https://${AUTHENTIK_DOMAIN}/application/o/authorize/" \
  --arg token_url "https://${AUTHENTIK_DOMAIN}/application/o/token/" \
  --arg user_url "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/" \
  '{
    "custom_providers": {
      "custom_oidc": {
        "Authentik": {
          "appid": $id,
          "secret": $secret,
          "authUrl": $auth_url,
          "tokenUrl": $token_url,
          "userinfoUrl": $user_url,
          "scopes": ["openid", "profile", "email"],
          "style": "custom",
          "icon": "key",
          "title": "Authentik"
        }
      }
    }
  }')

log_info "Applying sociallogin custom OIDC configuration to Nextcloud..."
# Using OCC config:app:set to write OIDC configuration
docker exec -i -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin custom_providers --value="$OIDC_CONFIG"

# Allow login without password (only SSO) if configured, or keep dual login options
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin prevent_create_email --value="0"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin auto_create_groups --value="1"

log_step "Nextcloud OIDC integration completed successfully!"
