#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Setup Script
# Installs and configures Social Login app for Authentik SSO
#
# Prerequisites:
#   - Nextcloud container running
#   - OAuth2 credentials in .env (NEXTCLOUD_OAUTH_CLIENT_ID, NEXTCLOUD_OAUTH_CLIENT_SECRET)
#   - AUTHENTIK_DOMAIN set
#
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Check prerequisites
if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ] || [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET must be set in .env"
  exit 1
fi

log_info "Installing Social Login app in Nextcloud..."

# Install Social Login app
docker exec -u www-data nextcloud php occ app:install sociallogin

if [ $? -ne 0 ]; then
  log_error "Failed to install Social Login app"
  exit 1
fi

log_info "Social Login app installed successfully!"

# Configure OIDC provider
log_info "Configuring Authentik OIDC provider..."

docker exec -u www-data nextcloud php occ config:app:set sociallogin \
  'custom_oidc' \
  'Authentik' \
  "${AUTHENTIK_DOMAIN}" \
  "${NEXTCLOUD_OAUTH_CLIENT_ID}" \
  "${NEXTCLOUD_OAUTH_CLIENT_SECRET}" \
  'openid profile email groups' \
  '' \
  '' \
  'https://${AUTHENTIK_DOMAIN}/.well-known/openid-configuration' \
  '1' \
  '1' \
  '0' \
  '0'

if [ $? -ne 0 ]; then
  log_error "Failed to configure OIDC provider"
  exit 1
fi

log_info "Authentik OIDC configured successfully!"
log_info ""
log_info "Next steps:"
log_info "  1. Restart Nextcloud container: docker compose -f stacks/storage/docker-compose.yml restart nextcloud"
log_info "  2. Login to Nextcloud using 'Login with Authentik' button"
log_info "  3. Verify user groups in Nextcloud admin panel"

exit 0
