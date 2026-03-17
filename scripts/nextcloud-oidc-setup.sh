#!/usr/bin/env bash
# =============================================================================
# nextcloud-oidc-setup.sh — Configure Nextcloud OIDC via Social Login App
# =============================================================================
# Run after authentik-setup.sh has generated NEXTCLOUD_OAUTH_CLIENT_ID/SECRET
#
# Usage:
#   ./scripts/nextcloud-oidc-setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
else
  echo "ERROR: .env not found" >&2
  exit 1
fi

CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
NEXTCLOUD_URL="https://nextcloud.${DOMAIN}"
AUTHENTIK_URL="https://auth.${DOMAIN}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_info() { echo -e "${BLUE}[--]${NC} $*"; }

log_info "Installing Social Login app in Nextcloud..."
docker exec -u www-data "${CONTAINER}" php occ app:install sociallogin 2>/dev/null \
  && log_ok "Installed sociallogin" \
  || log_info "sociallogin already installed"

docker exec -u www-data "${CONTAINER}" php occ app:enable sociallogin
log_ok "Social Login app enabled"

log_info "Configuring Authentik OIDC provider..."

PROVIDER_CONFIG=$(cat <<EOF
[{
  "name": "authentik",
  "title": "Authentik SSO",
  "clientId": "${NEXTCLOUD_OAUTH_CLIENT_ID}",
  "clientSecret": "${NEXTCLOUD_OAUTH_CLIENT_SECRET}",
  "discoveryUrl": "${AUTHENTIK_URL}/application/o/nextcloud/.well-known/openid-configuration",
  "scope": "openid email profile",
  "groupsClaim": "groups",
  "style": "openid",
  "defaultGroup": ""
}]
EOF
)

docker exec -u www-data "${CONTAINER}" php occ config:app:set sociallogin custom_providers \
  --value="${PROVIDER_CONFIG}"

log_ok "OIDC provider configured"

log_info "Enabling auto-create users on OAuth login..."
docker exec -u www-data "${CONTAINER}" php occ config:app:set sociallogin auto_create_groups --value="1"
docker exec -u www-data "${CONTAINER}" php occ config:app:set sociallogin disable_registration --value="0"

log_ok "Done!"
echo ""
echo "Test: ${NEXTCLOUD_URL}/login → 'Login with Authentik SSO'"
