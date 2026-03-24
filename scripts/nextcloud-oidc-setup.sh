#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup via Social Login App
# Configures Nextcloud to use Authentik as OIDC provider
# Usage: ./scripts/nextcloud-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

NEXTCLOUD_CONTAINER="nextcloud"

if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container is not running"
  exit 1
fi

log_info "Installing Social Login app..."
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install sociallogin 2>/dev/null || true

log_info "Configuring OIDC provider..."
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin custom_providers --value="$(cat <<EOF
{
  "custom_oidc": [
    {
      "name": "Authentik",
      "clientId": "${NEXTCLOUD_OAUTH_CLIENT_ID}",
      "clientSecret": "${NEXTCLOUD_OAUTH_CLIENT_SECRET}",
      "urlAuthorize": "https://${AUTHENTIK_DOMAIN}/application/o/authorize/",
      "urlAccessToken": "https://${AUTHENTIK_DOMAIN}/application/o/token/",
      "urlResourceOwnerDetails": "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/",
      "scope": "openid profile email",
      "displayNameClaim": "name",
      "groupsClaim": "groups",
      "style": "keycloak"
    }
  ]
}
EOF
)"

log_info "OIDC configured for Nextcloud"
