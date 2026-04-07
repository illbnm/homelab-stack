#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Setup Script
# Configures Nextcloud Social Login app for Authentik OIDC
# Requires: Nextcloud running, occ command available
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
elif [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
else
  log_error "No .env file found"
  exit 1
fi

# Required variables
NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
NEXTCLOUD_OAUTH_CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
NEXTCLOUD_OAUTH_CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"

if [ -z "$NEXTCLOUD_OAUTH_CLIENT_ID" ] || [ -z "$NEXTCLOUD_OAUTH_CLIENT_SECRET" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET not set in .env"
  log_info "Please run scripts/authentik-setup.sh first"
  exit 1
fi

# Helper to run occ command in Nextcloud container
occ() {
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"
}

log_step "Checking Nextcloud container..."
if ! docker ps | grep -q "$NEXTCLOUD_CONTAINER"; then
  log_error "Nextcloud container not running: $NEXTCLOUD_CONTAINER"
  exit 1
fi
log_info "Nextcloud container is running"

log_step "Installing Social Login app..."
if ! occ app:list | grep -q "sociallogin"; then
  log_info "Installing sociallogin app..."
  occ app:install sociallogin
else
  log_info "Social Login app already installed"
fi

log_step "Configuring Authentik OIDC provider..."

# Configure custom OIDC provider
occ config:app:set sociallogin custom_providers --value="$(cat <<EOF
{
  "custom_oidc": [
    {
      "name": "Authentik",
      "title": "Authentik",
      "clientId": "${NEXTCLOUD_OAUTH_CLIENT_ID}",
      "clientSecret": "${NEXTCLOUD_OAUTH_CLIENT_SECRET}",
      "authorizeUrl": "https://${AUTHENTIK_DOMAIN}/application/o/authorize/",
      "tokenUrl": "https://${AUTHENTIK_DOMAIN}/application/o/token/",
      "userInfoUrl": "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/",
      "logoutUrl": "https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/end-session/",
      "scope": "openid profile email",
      "groupsClaim": "groups",
      "style": "Authentik",
      "loginButtonAttributes": {
        "style": "background-color: #fd4b2d; color: white;"
      }
    }
  ]
}
EOF
)"

log_info "Authentik OIDC provider configured"

log_step "Configuring group mapping..."

# Map Authentik groups to Nextcloud groups
occ config:app:set sociallogin auto_create_groups --value="1"
occ config:app:set sociallogin create_disabled_users --value="0"
occ config:app:set sociallogin hide_default_login --value="0"

# Group mapping (optional - map Authentik groups to Nextcloud groups)
occ config:app:set sociallogin group_mapping --value="$(cat <<EOF
{
  "homelab-admins": "admin",
  "homelab-users": "users",
  "media-users": "media"
}
EOF
)"

log_info "Group mapping configured"

log_step "Testing OIDC configuration..."
if occ config:app:get sociallogin custom_providers | grep -q "Authentik"; then
  log_info "✓ OIDC configuration looks good"
else
  log_error "✗ OIDC configuration failed"
  exit 1
fi

log_step "Setup Complete!"
log_info "Nextcloud is now configured for Authentik OIDC"
echo
log_info "Next steps:"
log_info "  1. Visit https://nextcloud.${DOMAIN}"
log_info "  2. Click 'Login with Authentik' button"
log_info "  3. Authenticate with Authentik credentials"
log_info "  4. First login will create Nextcloud account automatically"
