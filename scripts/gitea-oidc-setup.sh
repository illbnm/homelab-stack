#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Gitea OIDC Setup Script
# Configures Gitea Authentik OIDC provider via API
# Requires: Gitea running, admin access
# Usage: ./scripts/gitea-oidc-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
elif [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
else
  log_error "No .env file found"
  exit 1
fi

# Required variables
GITEA_CONTAINER="${GITEA_CONTAINER:-gitea}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
GITEA_OAUTH_CLIENT_ID="${GITEA_OAUTH_CLIENT_ID:-}"
GITEA_OAUTH_CLIENT_SECRET="${GITEA_OAUTH_CLIENT_SECRET:-}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-root}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:-}"

if [ -z "$GITEA_OAUTH_CLIENT_ID" ] || [ -z "$GITEA_OAUTH_CLIENT_SECRET" ]; then
  log_error "GITEA_OAUTH_CLIENT_ID or GITEA_OAUTH_CLIENT_SECRET not set in .env"
  log_info "Please run scripts/authentik-setup.sh first"
  exit 1
fi

log_step "Checking Gitea container..."
if ! docker ps | grep -q "$GITEA_CONTAINER"; then
  log_error "Gitea container not running: $GITEA_CONTAINER"
  exit 1
fi
log_info "Gitea container is running"

log_step "Creating Authentik OAuth2 Application in Gitea..."

# Use Gitea CLI to add OAuth2 source
docker exec "$GITEA_CONTAINER" gitea admin auth add-oauth \
  --name "Authentik" \
  --provider "openidConnect" \
  --key "$GITEA_OAUTH_CLIENT_ID" \
  --secret "$GITEA_OAUTH_CLIENT_SECRET" \
  --auto-discover-url "https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration" \
  --group-claim-name "groups" \
  --admin-group "homelab-admins" \
  --restricted-group "" \
  2>/dev/null || {
  log_warn "OAuth2 source may already exist, updating..."
  docker exec "$GITEA_CONTAINER" gitea admin auth update-oauth \
    --id 1 \
    --name "Authentik" \
    --provider "openidConnect" \
    --key "$GITEA_OAUTH_CLIENT_ID" \
    --secret "$GITEA_OAUTH_CLIENT_SECRET" \
    --auto-discover-url "https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration" \
    --group-claim-name "groups" \
    --admin-group "homelab-admins" \
    --restricted-group ""
}

log_info "Authentik OAuth2 provider configured"

log_step "Verifying OAuth2 configuration..."
if docker exec "$GITEA_CONTAINER" gitea admin auth list | grep -q "Authentik"; then
  log_info "✓ OAuth2 configuration looks good"
else
  log_error "✗ OAuth2 configuration failed"
  exit 1
fi

log_step "Setup Complete!"
log_info "Gitea is now configured for Authentik OIDC"
echo
log_info "Next steps:"
log_info "  1. Visit https://git.${DOMAIN}"
log_info "  2. Click 'Sign in with Authentik' button"
log_info "  3. Authenticate with Authentik credentials"
log_info "  4. First login will create Gitea account automatically"
