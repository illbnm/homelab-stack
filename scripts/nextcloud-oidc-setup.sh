#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup — Authentik Integration
# Configures the Social Login app in Nextcloud to use Authentik as OIDC provider.
#
# Prerequisites:
#   - Nextcloud container running (stacks/storage)
#   - Authentik running with Nextcloud provider created (scripts/setup-authentik.sh)
#   - NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET set in .env
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

CONTAINER_NAME="nextcloud"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"
NEXTCLOUD_DOMAIN="nextcloud.${DOMAIN}"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET must be set in .env"
  log_error "Run scripts/setup-authentik.sh first to create the Nextcloud provider."
  exit 1
fi

if ! docker inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
  log_error "Nextcloud container '$CONTAINER_NAME' is not running."
  exit 1
fi

occ() {
  docker exec -u www-data "$CONTAINER_NAME" php occ "$@"
}

# ---------------------------------------------------------------------------
# Step 1: Install Social Login app
# ---------------------------------------------------------------------------
log_step "Installing Social Login app..."
if occ app:list --output=json 2>/dev/null | grep -q '"sociallogin"'; then
  log_info "Social Login app already installed"
else
  occ app:install sociallogin || log_warn "sociallogin may already be installed"
fi
occ app:enable sociallogin

# ---------------------------------------------------------------------------
# Step 2: Configure OpenID Connect provider
# ---------------------------------------------------------------------------
log_step "Configuring Authentik as OIDC provider..."

# Social Login stores its config as a JSON blob in the Nextcloud config
occ config:app:set sociallogin custom_oidc --value="$(cat <<EOFJSON
{
  "authentik": {
    "title": "Authentik",
    "authorizeUrl": "https://${AUTHENTIK_DOMAIN}/application/o/authorize/",
    "tokenUrl": "https://${AUTHENTIK_DOMAIN}/application/o/token/",
    "userInfoUrl": "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/",
    "logoutUrl": "https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/end-session/",
    "clientId": "${CLIENT_ID}",
    "clientSecret": "${CLIENT_SECRET}",
    "scope": "openid profile email",
    "groupsClaim": "groups",
    "style": "openid",
    "defaultGroup": ""
  }
}
EOFJSON
)"

# ---------------------------------------------------------------------------
# Step 3: Configure Social Login global settings
# ---------------------------------------------------------------------------
log_step "Setting Social Login global options..."

# Allow login without linking to existing account
occ config:app:set sociallogin allow_login_connect --value="1"
# Prevent password-less login when social account exists
occ config:app:set sociallogin prevent_create_email_exists --value="1"
# Auto-redirect to Authentik login (set to 0 to keep Nextcloud login page)
occ config:app:set sociallogin auto_redirect --value="0"

log_step "Nextcloud OIDC setup complete!"
log_info "Users can now log in via Authentik at https://${NEXTCLOUD_DOMAIN}"
log_info "The 'Login with Authentik' button will appear on the Nextcloud login page."
