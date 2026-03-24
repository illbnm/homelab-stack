#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup Script
# Installs and configures user_oidc app for Authentik integration
# Run AFTER: setup-authentik.sh and Nextcloud is running
#
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo "[ERROR] .env file not found"
  exit 1
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

NEXTCLOUD_CONTAINER="nextcloud"

# Check if Nextcloud is running
if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container is not running"
  exit 1
fi

# Check for required env vars
if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ] || [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET not set"
  log_info "Run scripts/setup-authentik.sh first"
  exit 1
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

log_step "Installing user_oidc app in Nextcloud..."

# Install user_oidc app
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ app:install user_oidc || {
  log_info "user_oidc may already be installed"
}

log_step "Configuring Authentik OIDC provider..."

# Configure OIDC provider
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ user_oidc:provider \
  --clientid="$NEXTCLOUD_OAUTH_CLIENT_ID" \
  --clientsecret="$NEXTCLOUD_OAUTH_CLIENT_SECRET" \
  --discoveryuri="$AUTHENTIK_URL/application/o/nextcloud/.well-known/openid-configuration" \
  --scope="openid email profile groups" \
  Authentik

log_step "Configuring Nextcloud settings..."

# Enable OIDC login
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:app:set user_oidc allow_login_user_oidc --value="1"
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:app:set user_oidc auto_provision --value="1"
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:app:set user_oidc auto_provision_claim --value="email"

# Disable password confirmation for OIDC users
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:system:set --value=false --type=boolean auth.user_oidc.disable_password_confirmation

log_step "Setting up group mapping..."

# Map Authentik groups to Nextcloud groups (requires group_oidc app)
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ app:install group_oidc || {
  log_info "group_oidc may already be installed"
}

# Enable group mapping
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:app:set group_oidc auto_create_groups --value="1"
docker exec -u www-data $NEXTCLOUD_CONTAINER php occ config:app:set group_oidc groups_claim --value="groups"

log_step "Nextcloud OIDC Setup Complete!"
echo ""
echo "Test login:"
echo "  1. Go to https://cloud.${DOMAIN}"
echo "  2. Click 'Login with Authentik'"
echo "  3. Use your Authentik credentials"
echo ""
echo "If login fails, check logs:"
echo "  docker logs $NEXTCLOUD_CONTAINER | grep oidc"