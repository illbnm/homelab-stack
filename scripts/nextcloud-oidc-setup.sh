#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Nextcloud OIDC Setup via Authentik
# Installs and configures the "Social Login" app for OIDC authentication.
# Requires: Nextcloud running, Authentik OIDC provider created
# Usage: ./scripts/nextcloud-oidc-setup.sh
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

# ── Prerequisites ───────────────────────────────────────────────────────────
NC_CONTAINER="${NC_CONTAINER:-nextcloud}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --container) NC_CONTAINER="$2"; shift 2 ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

if ! docker ps --format '{{.Names}}' | grep -q "^${NC_CONTAINER}$"; then
  log_error "Nextcloud container '${NC_CONTAINER}' is not running."
  log_error "Start the storage stack first: cd stacks/storage && docker compose up -d"
  exit 1
fi

# ── Install Social Login app ─────────────────────────────────────────────────
log_step "Installing Nextcloud Social Login app"

occ() {
  if $DRY_RUN; then
    echo "[DRY-RUN] docker exec -u www-data ${NC_CONTAINER} php occ $*"
  else
    docker exec -u www-data "$NC_CONTAINER" php occ "$@"
  fi
}

log_info "Enabling sociallogin app..."
occ app:enable sociallogin 2>/dev/null || {
  log_warn "sociallogin app not found, downloading..."
  occ app:install sociallogin
}
log_info "Social Login app enabled."

# ── Configure OIDC provider ─────────────────────────────────────────────────
log_step "Configuring Authentik OIDC provider in Nextcloud"

PROVIDER_ID="${NEXTCLOUD_OIDC_PROVIDER:-authentik}"

occ config:app:set sociallogin custom_providers --value="{\"${PROVIDER_ID}\":{\"name\":\"Authentik SSO\",\"title\":\"Login with Authentik\",\"authorizeUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/authorize/\",\"tokenUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/token/\",\"userInfoUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/userinfo/\",\"logoutUrl\":\"https://${AUTHENTIK_DOMAIN}/application/o/end-session/\",\"clientId\":\"${NEXTCLOUD_OIDC_CLIENT_ID}\",\"clientSecret\":\"${NEXTCLOUD_OIDC_CLIENT_SECRET}\",\"scope\":\"openid profile email\",\"profileUrl\":\"\",\"groupsClaim\":\"groups\",\"style\":\"\",\"defaultGroup\":\"\",\"displayNameClaim\":\"name\",\"buttonStyle\":\"\",\"uuidClaim\":\"sub\"}}"

log_info "Nextcloud OIDC configured with provider: ${PROVIDER_ID}"

# ── Verify ───────────────────────────────────────────────────────────────────
log_step "Verifying OIDC configuration"

if $DRY_RUN; then
  log_info "[DRY-RUN] Skipping verification."
else
  occ config:app:get sociallogin custom_providers
  log_info "Configuration saved. Users can now log in via 'Login with Authentik' on the Nextcloud login page."
fi

log_info "Done! Visit https://${NEXTCLOUD_DOMAIN} and click 'Login with Authentik'."
