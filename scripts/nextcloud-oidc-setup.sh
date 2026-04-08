#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup Script
# Configures Nextcloud to use Authentik as OAuth2/OIDC provider
# Requires: curl, jq, nextcloud occ command
# 
# Usage:
#   ./scripts/nextcloud-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

NEXTCLOUD_CONTAINER="nextcloud"
NEXTCLOUD_URL="https://cloud.${DOMAIN}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

# Check if Nextcloud is running
if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container is not running"
  exit 1
fi

log_step "Installing Nextcloud OIDC apps"

# Install OIDC Login app (for Nextcloud 25+)
log_info "Installing oidc_login app..."
docker exec "$NEXTCLOUD_CONTAINER" \
  sh -c "php occ app:install oidc_login --force" 2>/dev/null || \
  docker exec "$NEXTCLOUD_CONTAINER" \
  sh -c "php occ app:enable oidc_login" 2>/dev/null || \
  log_warn "oidc_login app may already be installed or not available"

# Install Social Login app as alternative
log_info "Installing social_login app..."
docker exec "$NEXTCLOUD_CONTAINER" \
  sh -c "php occ app:install social_login --force" 2>/dev/null || \
  docker exec "$NEXTCLOUD_CONTAINER" \
  sh -c "php occ app:enable social_login" 2>/dev/null || \
  log_warn "social_login app may already be installed or not available"

log_step "Configuring OIDC settings"

# Configure oidc_login settings
log_info "Setting up OIDC provider configuration..."

# Set OIDC settings via occ
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.provider_url --value="${AUTHENTIK_URL}" || true
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.client_id --value="${NEXTCLOUD_OAUTH_CLIENT_ID}" || true
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.client_secret --value="${NEXTCLOUD_OAUTH_CLIENT_SECRET}" || true
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.login_button_name --value="Authentik" || true
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.auto_login --value="true" || true
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.default_group --value="homelab-users" || true

# Allow OIDC login
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:set allow_login_with --value="oidc" || true

log_info "OIDC configuration applied"

log_step "Verifying configuration"
docker exec "$NEXTCLOUD_CONTAINER" php occ config:system:get oidc_login.provider_url || true

log_info "Nextcloud OIDC setup complete!"
log_info ""
log_info "Note: After setting up Authentik providers with setup-authentik.sh,"
log_info "users can log in using their Authentik credentials."
log_info ""
log_info "If using social_login instead, configure providers in Nextcloud Admin UI:"
log_info "  Admin → Social Login → Add Provider → OpenID Connect"