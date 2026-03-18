#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup Script
# Configures Nextcloud to use Authentik for OIDC login via the
# Social Login (sociallogin) app.
#
# Prerequisites:
#   - Nextcloud running and accessible
#   - Authentik SSO configured (run setup-authentik.sh first)
#   - NEXTCLOUD_OAUTH_CLIENT_ID and CLIENT_SECRET set in .env
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
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
DOMAIN="${DOMAIN:-localhost}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET must be set"
  echo "  Run ./scripts/setup-authentik.sh first to generate credentials"
  exit 1
fi

occ() {
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Nextcloud OIDC Setup — Authentik Integration"
echo "  Nextcloud: https://cloud.${DOMAIN}"
echo "  Authentik: https://${AUTHENTIK_DOMAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Step 1: Install Social Login App ────────────────────────────────────────
log_step "Installing Social Login app..."
if occ app:list 2>/dev/null | grep -q "sociallogin"; then
  log_info "Social Login app already installed"
else
  occ app:install sociallogin 2>/dev/null || occ app:enable sociallogin
  log_info "Social Login app installed and enabled"
fi

# ─── Step 2: Configure OIDC Provider ────────────────────────────────────────
log_step "Configuring Authentik OIDC provider..."

# Set social login settings
occ config:app:set sociallogin prevent_create_email_exists --value=1
occ config:app:set sociallogin update_profile_on_login --value=1
occ config:app:set sociallogin auto_create_groups --value=1

# Configure the OIDC provider
occ config:app:set sociallogin custom_oidc --value="{
  \"authentik\": {
    \"title\": \"Authentik\",
    \"authorizeUrl\": \"https://${AUTHENTIK_DOMAIN}/application/o/authorize/\",
    \"tokenUrl\": \"https://${AUTHENTIK_DOMAIN}/application/o/token/\",
    \"userInfoUrl\": \"https://${AUTHENTIK_DOMAIN}/application/o/userinfo/\",
    \"logoutUrl\": \"https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/end-session/\",
    \"clientId\": \"${CLIENT_ID}\",
    \"clientSecret\": \"${CLIENT_SECRET}\",
    \"scope\": \"openid email profile\",
    \"groupsClaim\": \"groups\",
    \"style\": \"openid\",
    \"defaultGroup\": \"\"
  }
}"

log_info "OIDC provider configured"

# ─── Step 3: Configure OIDC Login Button ─────────────────────────────────────
log_step "Configuring login page..."

# Allow login via OIDC button (don't hide default login)
occ config:app:set sociallogin hide_default_login --value=0

log_info "Login page configured — Authentik button will appear on login page"

# ─── Step 4: Verify ─────────────────────────────────────────────────────────
log_step "Verification"
echo ""
echo "  ✓ Social Login app: installed"
echo "  ✓ OIDC provider: configured"
echo ""
echo "  Test login:"
echo "  1. Open https://cloud.${DOMAIN}/login"
echo "  2. Click 'Authentik' button"
echo "  3. Login with Authentik credentials"
echo "  4. Verify user is created in Nextcloud"
echo ""
echo "  Authentik admin:"
echo "  - Provider: https://${AUTHENTIK_DOMAIN}/if/admin/#/providers"
echo "  - Application: https://${AUTHENTIK_DOMAIN}/if/admin/#/core/applications"
echo ""
log_info "Nextcloud OIDC setup complete"
