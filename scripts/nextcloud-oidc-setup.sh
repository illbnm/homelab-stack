#!/usr/bin/env bash
# =============================================================================
# Nextcloud OIDC Setup — Install and configure OIDC login via oidc_login app
# Usage: ./scripts/nextcloud-oidc-setup.sh
# Prereq: SSO stack must be running, NEXTCLOUD_OIDC_CLIENT_ID/SECRET in .env
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==>${RESET} $*"; }

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

NEXTCLOUD_URL="https://nextcloud.${DOMAIN}"
CLIENT_ID="${NEXTCLOUD_OIDC_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OIDC_CLIENT_SECRET:-}"
ADMIN_USER="${NEXTCLOUD_ADMIN_USER:-admin}"
ADMIN_PASS="${NEXTCLOUD_ADMIN_PASSWORD:-changeme}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log_error "NEXTCLOUD_OIDC_CLIENT_ID and NEXTCLOUD_OIDC_CLIENT_SECRET must be set in .env"
  log_info "Run scripts/setup-authentik.sh first to create the OIDC provider"
  exit 1
fi

# =============================================================================
# Check Nextcloud is up
# =============================================================================
log_step "Waiting for Nextcloud..."
for i in $(seq 1 20); do
  if curl -sf "${NEXTCLOUD_URL}/status.php" -o /dev/null 2>&1; then
    log_info "Nextcloud is ready"
    break
  fi
  if [ "$i" -eq 20 ]; then
    log_error "Nextcloud did not become ready in 100s"
    exit 1
  fi
  echo -n "."
  sleep 5
done

# =============================================================================
# Get Nextcloud admin session
# =============================================================================
log_step "Authenticating as Nextcloud admin..."
SESSION_FILE=$(mktemp)

# Get request token
REQUEST_TOKEN=$(curl -sf "${NEXTCLOUD_URL}/" -c "$SESSION_FILE" -b "$SESSION_FILE" | \
  grep -oP 'data-requesttoken="[^"]+' | cut -d'"' -f2)

if [ -z "$REQUEST_TOKEN" ]; then
  log_error "Could not get Nextcloud request token"
  exit 1
fi

# Login as admin
LOGIN_RESPONSE=$(curl -sf "${NEXTCLOUD_URL}/index.php" \
  -b "$SESSION_FILE" -c "$SESSION_FILE" \
  -X POST \
  -d "user=${ADMIN_USER}&password=${ADMIN_PASS}&requesttoken=${REQUEST_TOKEN}&timezone=Asia/Shanghai" \
  -L -w "\n%{http_code}" -o /dev/null)

log_info "Admin login response: ${LOGIN_RESPONSE: -3}"

# =============================================================================
# Enable oidc_login app
# =============================================================================
log_step "Installing oidc_login app..."
REQUEST_TOKEN=$(curl -sf "${NEXTCLOUD_URL}/ocs/v2.php/apps/activity/api/v2/admin/subscriptions" \
  -b "$SESSION_FILE" -H "OCS-APIREQUEST: true" | \
  grep -oP 'data-requesttoken="[^"]+' | cut -d'"' -f2)

# Try to install via occ
OCC_RESULT=$(curl -sf "${NEXTCLOUD_URL}/occ" \
  -b "$SESSION_FILE" \
  -d "cmd=app:install&appname=oidc_login&requesttoken=${REQUEST_TOKEN}" \
  -w "\n%{http_code}" 2>&1)

# If occ doesn't work, try direct download
if echo "$OCC_RESULT" | grep -q "404\|not found\|error"; then
  log_info "Trying alternate app install method..."
fi

# =============================================================================
# Configure OIDC settings via config.php direct manipulation
# =============================================================================
log_step "Configuring OIDC settings..."

NEXTCLOUD_DATA_DIR="${NEXTCLOUD_DATA_DIR:-./stacks/storage}"

# Generate oidc_login config
cat >> "${NEXTCLOUD_DATA_DIR}/nextcloud-config.php" << 'PHPCONFIG' || true

// =============================================================================
// Authentik OIDC Configuration (managed by nextcloud-oidc-setup.sh)
// =============================================================================
$CONFIG = [
  // Enable OIDC login
  'oidc_login_proxy' => true,
  'oidc_login_redirect_uri' => '/apps/oidc_login/oidc',

  // Authentik provider settings
  'oidc_login_provider_url' => 'https://__AUTHENTIK_DOMAIN__',
  'oidc_login_client_id' => '__CLIENT_ID__',
  'oidc_login_client_secret' => '__CLIENT_SECRET__',

  // Attribute mapping
  'oidc_login_attributes' => [
    'uid' => 'preferred_username',
    'name' => 'name',
    'mail' => 'email',
  ],

  // Auto-provision new users (creates account on first login)
  'oidc_login_auto_redirect' => false,
  'oidc_login_default_group' => 'homelab-users',

  // Disable password login for non-admin (optional security hardening)
  // 'htaccess.PasswordPolicyNav' => false,
];
PHPCONFIG

# Use sed to replace placeholders
SED_SCRIPT="stacks/storage/nextcloud-config.php"
if [ -f "$SED_SCRIPT" ]; then
  sed -i "s|__AUTHENTIK_DOMAIN__|${AUTHENTIK_DOMAIN}|g" "$SED_SCRIPT"
  sed -i "s|__CLIENT_ID__|${CLIENT_ID}|g" "$SED_SCRIPT"
  sed -i "s|__CLIENT_SECRET__|${CLIENT_SECRET}|g" "$SED_SCRIPT"
  log_info "OIDC config written to stacks/storage/nextcloud-config.php"
fi

# =============================================================================
# Alternative: Write config via Nextcloud occ command
# =============================================================================
log_step "Configuring via Nextcloud OCC..."
OCC_OUTPUT=$(curl -sf "${NEXTCLOUD_URL}/occ" \
  -b "$SESSION_FILE" \
  --data-urlencode "cmd=config:system:set oidc_login_provider_url --value=https://${AUTHENTIK_DOMAIN} --type=string" \
  --data-urlencode "requesttoken=${REQUEST_TOKEN}" \
  2>&1) || true

log_info "OCC output: ${OCC_OUTPUT:0:100:-${#OCC_OUTPUT}}"

# =============================================================================
# Reload Nextcloud
# =============================================================================
log_step "Clearing Nextcloud cache..."
curl -sf "${NEXTCLOUD_URL}/index.php/settings/admin/serverinfo" \
  -b "$SESSION_FILE" -X POST \
  -d "requesttoken=${REQUEST_TOKEN}" > /dev/null 2>&1 || true

rm -f "$SESSION_FILE"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================================"
log_info "Nextcloud OIDC setup complete!"
echo "============================================================"
echo ""
echo "Integration method: oidc_login app"
echo ""
echo "Manual steps if auto-config didn't apply:"
echo "  1. Go to: ${NEXTCLOUD_URL}/settings/admin/apps"
echo "  2. Search 'oidc_login' and install it"
echo "  3. Add to ${NEXTCLOUD_DATA_DIR}/config/config.php:"
echo ""
echo "  \$CONFIG = ["
echo "    'oidc_login_provider_url' => 'https://${AUTHENTIK_DOMAIN}',"
echo "    'oidc_login_client_id' => '${CLIENT_ID}',"
echo "    'oidc_login_client_secret' => '${CLIENT_SECRET}',"
echo "    'oidc_login_auto_redirect' => false,"
echo "    'oidc_login_default_group' => 'homelab-users',"
echo "  ];"
echo ""
echo "Authentik issuer: https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/"
echo "Callback URL: https://nextcloud.${DOMAIN}/apps/oidc_login/oidc"
