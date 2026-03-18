#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Nextcloud OIDC Configuration Helper
# Configures Nextcloud to use Authentik as OIDC identity provider.
# Prerequisites:
#   - SSO stack running (stacks/sso/)
#   - OIDC provider created via scripts/setup-authentik.sh
#   - Nextcloud user_oidc app installed
# Usage:
#   ./scripts/nextcloud-oidc-setup.sh            # Apply config
#   ./scripts/nextcloud-oidc-setup.sh --dry-run   # Show what would be done
#   ./scripts/nextcloud-oidc-setup.sh --install-app  # Also install user_oidc app
# =============================================================================
set -euo pipefail

DRY_RUN=false
INSTALL_APP=false
for arg in "${1:-}"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --install-app) INSTALL_APP=true ;;
    *) echo "Usage: $0 [--dry-run] [--install-app]"; exit 1 ;;
  esac
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_dry()   { echo -e "${DIM}[DRY-RUN]${RESET} $*"; }

# ---------------------------------------------------------------------------
# Configurable values
# ---------------------------------------------------------------------------
NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
NEXTCLOUD_URL="https://nextcloud.${DOMAIN}"

CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  log_error "NEXTCLOUD_OAUTH_CLIENT_ID and NEXTCLOUD_OAUTH_CLIENT_SECRET must be set in .env"
  log_error "Run scripts/setup-authentik.sh first to create the OIDC provider."
  exit 1
fi

# Discover provider slug from Authentik
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN not set in .env"
  exit 1
fi

PROVIDER_SLUG=$(curl -sf "https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}/api/v3/providers/oauth2/?name=Nextcloud+Provider" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.results[0].application_slug // empty')

if [ -z "$PROVIDER_SLUG" ]; then
  PROVIDER_SLUG="nextcloud"
  log_warn "Could not auto-detect provider slug, using default: $PROVIDER_SLUG"
fi

OIDC_DISCOVERY_URI="${AUTHENTIK_URL}/application/o/${PROVIDER_SLUG}/"

# ---------------------------------------------------------------------------
# Optionally install user_oidc app
# ---------------------------------------------------------------------------
if $INSTALL_APP; then
  if $DRY_RUN; then
    log_dry "Would install user_oidc app: docker exec $NEXTCLOUD_CONTAINER occ app:enable user_oidc"
  else
    log_info "Installing user_oidc app..."
    if docker exec "$NEXTCLOUD_CONTAINER" occ app:enable user_oidc 2>&1; then
      log_info "user_oidc app enabled"
    else
      log_warn "user_oidc app may already be enabled or install failed"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Configure OIDC in Nextcloud via occ
# ---------------------------------------------------------------------------
# Build occ command arguments
OCC_ARGS=(
  user_oidc:provider
  Nextcloud
  "$CLIENT_ID"
  "$CLIENT_SECRET"
  "$OIDC_DISCOVERY_URI"
)

# Additional settings
NEXTCLOUD_SETTINGS=(
  "mapping_uid=sub"
  "mapping_email=email"
  "scope=openid email profile"
  "uid_claim=sub"
)

log_step "Configuring Nextcloud OIDC provider: Nextcloud"
log_info "  Discovery URI: $OIDC_DISCOVERY_URI"
log_info "  Client ID:     $CLIENT_ID"
log_info "  Container:     $NEXTCLOUD_CONTAINER"

if $DRY_RUN; then
  log_dry "docker exec $NEXTCLOUD_CONTAINER occ ${OCC_ARGS[*]}"
  for s in "${NEXTCLOUD_SETTINGS[@]}"; do
    log_dry "docker exec $NEXTCLOUD_CONTAINER occ config:app:set user_oidc $s"
  done
else
  # Check if provider already exists
  if docker exec "$NEXTCLOUD_CONTAINER" occ user_oidc:provider Nextcloud 2>/dev/null; then
    log_warn "Provider 'Nextcloud' already exists. Removing and recreating..."
    docker exec "$NEXTCLOUD_CONTAINER" occ user_oidc:provider Nextcloud --delete 2>/dev/null || true
  fi

  # Create provider
  docker exec "$NEXTCLOUD_CONTAINER" occ "${OCC_ARGS[@]}" 2>&1

  # Apply settings
  for s in "${NEXTCLOUD_SETTINGS[@]}"; do
    docker exec "$NEXTCLOUD_CONTAINER" occ config:app:set user_oidc "$s" 2>/dev/null || true
  done

  log_info "Nextcloud OIDC provider configured successfully"
fi

# ---------------------------------------------------------------------------
# Set Nextcloud to allow login via OIDC only (optional — commented out)
# ---------------------------------------------------------------------------
log_step "Optional: Restrict login to OIDC only"
log_info "To restrict login to OIDC, run:"
echo -e "  ${CYAN}docker exec $NEXTCLOUD_CONTAINER occ config:app:set user_oidc allow_login_using true${RESET}"
echo -e "  ${CYAN}docker exec $NEXTCLOUD_CONTAINER occ config:system:set login_form_auto true${RESET}"

log_step "Done!"
log_info "Nextcloud OIDC integration complete"
log_info "Test: visit $NEXTCLOUD_URL → click 'Log in with Nextcloud' (OIDC button)"
