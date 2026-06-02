#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup via Authentik
# Configures the OIDC social login app in Nextcloud using occ commands.
#
# Prerequisites:
#   1. Nextcloud container running (nextcloud)
#   2. Authentik SSO stack running with OIDC provider for Nextcloud created
#   3. NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET in .env
#
# Usage:
#   ./scripts/nextcloud-oidc-setup.sh
#
# ARM64 compatible — works on ARM64 and x86_64.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

log_step "Nextcloud OIDC Setup via Authentik"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container '${NEXTCLOUD_CONTAINER}' is not running"
  log_info "Available containers:"
  docker ps --format '{{.Names}}' 2>/dev/null || true
  exit 1
fi

if [[ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ]] || [[ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID or NEXTCLOUD_OAUTH_CLIENT_SECRET not set in .env"
  log_info "Run ./scripts/setup-authentik.sh first to create the Nextcloud OIDC provider"
  exit 1
fi

log_info "Installing 'Social Login' app in Nextcloud..."
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install sociallogin 2>/dev/null || \
  log_warn "sociallogin app may already be installed"

docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:enable sociallogin 2>/dev/null || true

log_info "Configuring Custom OIDC provider 'Authentik'..."

local OIDC_ISSUER="$AUTHENTIK_URL/application/o/nextcloud/"
local OIDC_DISCOVERY="$AUTHENTIK_URL/application/o/nextcloud/.well-known/openid-configuration"

docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set \
  sociallogin custom_providers -- \
  --value "$(jq -n \
    --arg name "Authentik" \
    --arg title "Login with Authentik" \
    --arg authurl "$AUTHENTIK_URL/application/o/authorize/" \
    --arg tokenurl "$AUTHENTIK_URL/application/o/token/" \
    --arg userurl "$AUTHENTIK_URL/application/o/userinfo/" \
    --arg clientid "$NEXTCLOUD_OAUTH_CLIENT_ID" \
    --arg clientsecret "$NEXTCLOUD_OAUTH_CLIENT_SECRET" \
    --arg scope "openid profile email" \
    --arg provider "custom_oidc" \
    '{
      "Authentik": {
        "name": $name,
        "title": $title,
        "authorizeUrl": $authurl,
        "tokenUrl": $tokenurl,
        "userInfoUrl": $userurl,
        "clientId": $clientid,
        "clientSecret": $clientsecret,
        "scope": $scope,
        "provider": $provider,
        "groupsClaim": "groups",
        "style": "",
        "defaultGroup": "",
        "sendIdTokenHint": true,
        "displayNameClaim": "name",
        "logoutUrl": "https://auth.'${DOMAIN}'/application/o/nextcloud/end-session/"
      }
    }')" 2>/dev/null

log_info "Nextcloud OIDC configured successfully"
log_info "Users can now log in at: https://nextcloud.${DOMAIN}"
log_info "The 'Login with Authentik' button should appear on the Nextcloud login page"
