#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup
# Installs and configures OIDC Login app for Nextcloud
# Requires: curl, jq
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

NEXTCLOUD_URL="https://cloud.${DOMAIN}"
NEXTCLOUD_CONTAINER="nextcloud"

# Check if Nextcloud container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
  log_error "Nextcloud container not found. Make sure it's running."
  exit 1
fi

log_step "Installing OIDC Login app in Nextcloud..."

# Download OIDC Login app
docker exec -u www-data "$NEXTCLOUD_CONTAINER" bash -c "
  cd /var/www/html/apps || cd /var/www/html/custom_apps
  if [ ! -d 'oidc_login' ]; then
    echo 'Downloading OIDC Login app...'
    curl -sL 'https://github.com/nextcloud/oidc_login/releases/download/v5.0.0/oidc_login-5.0.0.tar.gz' | tar xz
    mv oidc_login-5.0.0 oidc_login 2>/dev/null || true
  fi
  php occ app:enable oidc_login || true
"

log_step "Configuring OIDC Login settings..."

# Configure OIDC settings via occ
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.provider_url --value="https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/" || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.client_id --value="${NEXTCLOUD_OIDC_CLIENT_ID}" || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.client_secret --value="${NEXTCLOUD_OIDC_CLIENT_SECRET}" || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.login_button_name --value="Login with Authentik" || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.auto_redirect --value="true" || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set oidc_login.default_group --value="homelab-users" || true

# Disable password login (optional, for SSO-only)
# docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:system:set allow_password_login --value="false" || true

log_info "Nextcloud OIDC configuration complete!"
log_info "OIDC Provider URL: https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/"
log_info ""
log_info "IMPORTANT: If you set auto_redirect=true, users will be automatically"
log_info "redirected to Authentik for login. To access the Nextcloud admin panel,"
log_info "add ?direct=1 to the URL: ${NEXTCLOUD_URL}/?direct=1"