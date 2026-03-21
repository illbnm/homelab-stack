#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup Script
# Configures OIDC Login app in Nextcloud for Authentik SSO
#
# Prerequisites:
#   - Nextcloud is running and accessible
#   - OIDC Login app is installed (via apps menu or manually)
#   - AUTHENTIK_DOMAIN, NEXTCLOUD_OAUTH_CLIENT_ID, NEXTCLOUD_OAUTH_CLIENT_SECRET are set
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

# Check required variables
if [ -z "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID is not set. Run scripts/setup-authentik.sh first."
  exit 1
fi

if [ -z "${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_SECRET is not set. Run scripts/setup-authentik.sh first."
  exit 1
fi

if [ -z "${AUTHENTIK_DOMAIN:-}" ]; then
  log_error "AUTHENTIK_DOMAIN is not set in .env"
  exit 1
fi

if [ -z "${DOMAIN:-}" ]; then
  log_error "DOMAIN is not set in .env"
  exit 1
fi

log_step "Configuring Nextcloud OIDC Login"

# OCC command helper (run inside Nextcloud container)
occ() {
  docker exec -u www-data nextcloud php occ "$@"
}

# Wait for Nextcloud to be ready
log_info "Waiting for Nextcloud to be ready..."
for i in $(seq 1 30); do
  if docker exec nextcloud curl -sf http://localhost:80/status.php > /dev/null 2>&1; then
    log_info "Nextcloud is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    log_error "Nextcloud did not become ready in 150s"
    exit 1
  fi
  echo -n "."
  sleep 5
done

# Enable OIDC Login app if not already enabled
log_info "Enabling OIDC Login app..."
if ! occ app:list | grep -q oidc_login; then
  occ app:install oidc_login || log_warn "OIDC Login app may already be installed"
fi
occ app:enable oidc_login || true

# Configure OIDC settings
log_info "Configuring OIDC settings..."

# Basic OIDC configuration
occ config:app:set oidc_login oidc_discover_uri --value "https://${AUTHENTIK_DOMAIN}/.well-known/openid-configuration"
occ config:app:set oidc_login oidc_client_id --value "${NEXTCLOUD_OAUTH_CLIENT_ID}"
occ config:app:set oidc_login oidc_client_secret --value "${NEXTCLOUD_OAUTH_CLIENT_SECRET}"
occ config:app:set oidc_login oidc_redirect_uri --value "https://nextcloud.${DOMAIN}/apps/oidc_login/oidc"

# User provisioning settings
occ config:app:set oidc_login oidc_auto_provision --value "true"
occ config:app:set oidc_login oidc_auto_create --value "true"
occ config:app:set oidc_login oidc_persistent_login --value "true"

# Attribute mapping
occ config:app:set oidc_login oidc_id_attribute --value "sub"
occ config:app:set oidc_login oidc_name_attribute --value "name"
occ config:app:set oidc_login oidc_mail_attribute --value "email"
occ config:app:set oidc_login oidc_quota_attribute --value "quota"
occ config:app:set oidc_login oidc_photo_attribute --value "picture"

# Group mapping (optional)
occ config:app:set oidc_login oidc_group_mapping --value '{"Authentik Admins":"admin","Authentik Managers":"manager"}'

# Security settings
occ config:app:set oidc_login oidc_tls_verify --value "true"
occ config:app:set oidc_login oidc_login_button_text --value "Login with Authentik"
occ config:app:set oidc_login oidc_logout_url --value "https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/end-session/"

log_step "Nextcloud OIDC configuration complete!"
log_info "Users can now login at: https://nextcloud.${DOMAIN}"
log_info "OIDC callback URL: https://nextcloud.${DOMAIN}/apps/oidc_login/oidc"
log_info ""
log_info "To test: Open Nextcloud in browser and click 'Login with Authentik'"
