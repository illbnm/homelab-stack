#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup Script
# Configures Nextcloud to use Authentik as OIDC provider via sociallogin app.
#
# Prerequisites:
#   1. Nextcloud container running
#   2. Authentik SSO stack running and providers created
#   3. NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET in .env
#
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

NEXTCLOUD_CONTAINER="nextcloud"
AUTHENTIK_URL="https://auth.${DOMAIN}"

# Verify required variables
if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ] || [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET is not set"
  log_error "Run ./scripts/setup-authentik.sh first to create OIDC providers"
  exit 1
fi

log_info "Configuring Nextcloud OIDC with Authentik..."

# Enable sociallogin app via OCC
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:enable sociallogin 2>/dev/null || {
  log_info "Installing sociallogin app..."
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install sociallogin
}

# Configure custom OIDC provider
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set \\
  sociallogin custom_providers --value='{
    "Authentik": {
      "name": "Authentik",
      "title": "Login with Authentik",
      "authorizeUrl": "'"$AUTHENTIK_URL"'/application/o/authorize/",
      "tokenUrl": "'"$AUTHENTIK_URL"'/application/o/token/",
      "userInfoUrl": "'"$AUTHENTIK_URL"'/application/o/userinfo/",
      "logoutUrl": "'"$AUTHENTIK_URL"'/application/o/nextcloud/end-session/",
      "clientId": "'"$NEXTCLOUD_OAUTH_CLIENT_ID"'",
      "clientSecret": "'"$NEXTCLOUD_OAUTH_CLIENT_SECRET"'",
      "scope": "openid profile email",
      "profileUrl": "",
      "displayNameClaim": "name",
      "groupsClaim": "groups",
      "defaultGroup": "homelab-users",
      "style": "",
      "faIcon": "",
      "order": 1
    }
  }'

log_info "Nextcloud OIDC setup complete!"
log_info "Login to Nextcloud and you should see 'Login with Authentik' button."
echo ""
echo -e "  ${BOLD}Nextcloud URL:${RESET}           https://nextcloud.${DOMAIN}"
echo -e "  ${BOLD}Authentik Provider:${RESET}      https://auth.${DOMAIN}/if/admin/#/core/providers"