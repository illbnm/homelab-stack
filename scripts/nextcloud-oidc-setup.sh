#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup Script
# Installs and configures sociallogin app for Authentik SSO
#
# Prerequisites:
#   - Nextcloud container is running
#   - OIDC provider already created in Authentik (via setup-authentik.sh)
#   - Environment variables set in .env
#
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# ------------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------------
log_step "Checking prerequisites..."

if ! docker ps | grep -q nextcloud; then
  log_error "Nextcloud container is not running"
  log_info "Start it with: cd stacks/storage && docker compose up -d"
  exit 1
fi

if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ] || [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET is not set"
  log_info "Run scripts/setup-authentik.sh first"
  exit 1
fi

# ------------------------------------------------------------------
# Install sociallogin app
# ------------------------------------------------------------------
log_step "Installing sociallogin app..."

docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -u www-data -T nextcloud \
  php occ app:install sociallogin || log_warn "sociallogin already installed"

# ------------------------------------------------------------------
# Configure OIDC provider
# ------------------------------------------------------------------
log_step "Configuring Authentik OIDC provider..."

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

# Create custom OIDC provider configuration
cat <<EOF | docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -T nextcloud php occ config:import
{
  "system": {
    "social_login_auto_create_new_user": true,
    "social_login_update_user_groups": true,
    "social_login_disable_registration": false,
    "custom_oidc": [
      {
        "name": "Authentik",
        "title": "Authentik SSO",
        "clientId": "${NEXTCLOUD_OAUTH_CLIENT_ID}",
        "clientSecret": "${NEXTCLOUD_OAUTH_CLIENT_SECRET}",
        "authorizeUrl": "${AUTHENTIK_URL}/application/o/authorize/",
        "tokenUrl": "${AUTHENTIK_URL}/application/o/token/",
        "userInfoUrl": "${AUTHENTIK_URL}/application/o/userinfo/",
        "logoutUrl": "${AUTHENTIK_URL}/application/o/nextcloud/end-session/",
        "scope": "openid profile email",
        "groupsClaim": "groups",
        "style": "authentik",
        "defaultGroup": "homelab-users",
        "groupMapping": {
          "homelab-admins": "admin",
          "media-users": "media-users"
        }
      }
    ]
  }
}
EOF

log_step "Enabling sociallogin app..."

docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -u www-data -T nextcloud \
  php occ app:enable sociallogin

# ------------------------------------------------------------------
# Configure group mapping
# ------------------------------------------------------------------
log_step "Creating Nextcloud groups..."

docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -T nextcloud php occ group:add admin 2>/dev/null || true
docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -T nextcloud php occ group:add homelab-users 2>/dev/null || true
docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -T nextcloud php occ group:add media-users 2>/dev/null || true

# ------------------------------------------------------------------
# Verify configuration
# ------------------------------------------------------------------
log_step "Verifying configuration..."

docker compose -f "$ROOT_DIR/stacks/storage/docker-compose.yml" exec -u www-data -T nextcloud \
  php occ config:list sociallogin || true

log_info "✓ Nextcloud OIDC configuration complete!"
log_info "Login at: https://nextcloud.${DOMAIN}"
log_info "Click 'Login with Authentik' to use SSO"
