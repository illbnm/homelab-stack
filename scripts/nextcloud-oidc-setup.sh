#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup Script
# Installs the 'sociallogin' app and configures Authentik OIDC for Nextcloud.
#
# Usage:
#   ./scripts/nextcloud-oidc-setup.sh
#
# Prerequisites:
#   - Nextcloud container running
#   - Authentik SSO stack running with OIDC provider created
#   - NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET in .env
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

CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

# Validate required vars
if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ] || [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET must be set."
  log_error "Run scripts/setup-authentik.sh first to create the OIDC provider."
  exit 1
fi

# Check container exists
if ! docker inspect "$CONTAINER" > /dev/null 2>&1; then
  log_error "Container '$CONTAINER' not found. Is Nextcloud running?"
  exit 1
fi

# Step 1: Install sociallogin app
log_step "Installing sociallogin app..."
if docker exec -u www-data "$CONTAINER" php occ app:list | grep -q '"sociallogin"'; then
  log_info "sociallogin app already installed"
else
  docker exec -u www-data "$CONTAINER" php occ app:install sociallogin
  log_info "sociallogin app installed"
fi

# Step 2: Enable sociallogin app
log_step "Enabling sociallogin app..."
docker exec -u www-data "$CONTAINER" php occ app:enable sociallogin
log_info "sociallogin app enabled"

# Step 3: Configure OIDC provider
log_step "Configuring Authentik OIDC provider..."

OIDC_CONFIG=$(cat <<EOF
[{
  "name": "Authentik",
  "clientId": "${NEXTCLOUD_OAUTH_CLIENT_ID}",
  "clientSecret": "${NEXTCLOUD_OAUTH_CLIENT_SECRET}",
  "authorizeUrl": "${AUTHENTIK_URL}/application/o/authorize/",
  "tokenUrl": "${AUTHENTIK_URL}/application/o/token/",
  "userInfoUrl": "${AUTHENTIK_URL}/application/o/userinfo/",
  "logoutUrl": "${AUTHENTIK_URL}/application/o/nextcloud/end-session/",
  "scopes": "openid profile email",
  "groupsClaim": "groups",
  "style": "Authentik"
}]
EOF
)

docker exec -u www-data "$CONTAINER" php occ config:app:set \
  sociallogin custom_oidc_providers --value="$OIDC_CONFIG" > /dev/null

log_info "OIDC provider configured"

# Step 4: Configure sociallogin settings
log_step "Configuring sociallogin settings..."

docker exec -u www-data "$CONTAINER" php occ config:app:set \
  sociallogin allow_login_social_registration --value="true" > /dev/null 2>/dev/null || true

docker exec -u www-data "$CONTAINER" php occ config:app:set \
  sociallogin create_disabled_users --value="0" > /dev/null 2>/dev/null || true

docker exec -u www-data "$CONTAINER" php occ config:app:set \
  sociallogin update_user_on_login --value="1" > /dev/null 2>/dev/null || true

log_info "Sociallogin settings configured"

# Step 5: Verify
log_step "Verifying configuration..."
CONFIG_CHECK=$(docker exec -u www-data "$CONTAINER" php occ config:app:get sociallogin custom_oidc_providers 2>/dev/null || echo "")
if [ -n "$CONFIG_CHECK" ] && [ "$CONFIG_CHECK" != "" ]; then
  log_info "OIDC provider verified in Nextcloud config"
else
  log_warn "Could not verify OIDC config — check Nextcloud admin UI manually"
fi

log_step "Nextcloud OIDC setup complete!"
log_info ""
log_info "Summary:"
log_info "  Provider name: Authentik"
log_info "  Client ID:     ${NEXTCLOUD_OAUTH_CLIENT_ID}"
log_info "  Auth URL:      ${AUTHENTIK_URL}/application/o/authorize/"
log_info "  Token URL:     ${AUTHENTIK_URL}/application/o/token/"
log_info "  UserInfo URL:  ${AUTHENTIK_URL}/application/o/userinfo/"
log_info ""
log_info "Users can now login via Authentik from the Nextcloud login page."
log_info "The 'Login with Authentik' button will appear automatically."
