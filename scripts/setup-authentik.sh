#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all HomeLab services
# Requires: curl, jq, docker compose must up
# Usage: ./scripts/setup-authentik.sh [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SSO_DIR="$ROOT_DIR/stacks/sso"

# Load environment variables
if [ -f "$SSO_DIR/.env" ]; then
  set -a; source "$SSO_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Configuration
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
DRY_RUN="${1:-}"

# Check prerequisites
if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
  log_error "Required tools: curl, jq"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ===================================================================
# Helper functions
# ===================================================================

wait_for_authentik() {
  log_step "Waiting for Authentik to be ready..."
  local max_attempts=30
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>&1; then
      log_info "Authentik is ready!"
      return 0
    fi
    log_warn "Attempt $((attempt + 1))/$max_attempts failed, waiting..."
    sleep 2
    attempt=$((attempt + 1))
  done
  
  log_error "Authentik did not become ready after $max_attempts attempts"
  return 1
}

get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk' 2>/dev/null
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk' 2>/dev/null
}

create_oidc_provider() {
  local name="$1"
  local slug="$2"
  local redirect_uri="$3"
  local client_id_var="$4"
  local client_secret_var="$5"
  
  log_step "Creating OIDC provider: $name"
  
  # Get required resources
  local authorization_flow=$(get_default_flow "default-authentication-flow")
  local signing_key=$(get_signing_key)
  
  if [ -z "$authorization_flow" ] || [ -z "$signing_key" ]; then
    log_error "Failed to get required resources for $name"
    return 1
  fi
  
  # Check if provider already exists
  local existing
  existing=$(curl -sf "$API_URL/providers/oauth2/?name=$slug" \
    -H "$AUTH_HEADER" | jq -r '.results | length')
  
  if [ "$existing" -gt 0 ]; then
    log_warn "Provider $slug already exists, skipping..."
    return 0
  fi
  
  # Create provider
  local payload=$(cat <<EOF
{
  "name": "$name",
  "authorization_flow": "$authorization_flow",
  "client_type": "confidential",
  "client_id": "auto-generated",
  "redirect_uris": "$redirect_uri",
  "signing_key": "$signing_key",
  "sub_mode": "hashed_user_id",
  "include_claims_in_id_token": [
    "email",
    "groups",
    "given_name",
    "family_name"
  ],
  "access_code_validity": 31536000
}
EOF
)
  
  local response
  response=$(curl -sf -X POST "$API_URL/providers/oauth2/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload")
  
  if [ $? -ne 0 ]; then
    log_error "Failed to create provider $name"
    return 1
  fi
  
  local provider_pk=$(echo "$response" | jq -r '.pk')
  local client_id=$(echo "$response" | jq -r '.client_id')
  local client_secret=$(echo "$response" | jq -r '.client_secret')
  
  log_info "✓ Provider created: $name"
  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"
  log_info "  Client Secret: $client_secret"
  
  # Update .env with credentials
  if [ "$DRY_RUN" != "true" ]; then
    sed -i.bak "e " "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$SSO_DIR/.env"
    sed -i.bak "e "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$SSO_DIR/.env"
    log_info "  Updated .env with credentials"
  else
    log_info "[DRY-RUN] Would update .env with:"
    log_info "  ${client_id_var}=$client_id"
    log_info"  ${client_secret_var}=$client_secret"
  fi
  
  # Create application
  local app_payload=$(cat <<EOF
{
  "name": "$name",
  "slug": "$slug",
  "provider": $provider_pk",
  "policy_engine_mode": "all",
  "launch_url": "https://${DOMAIN}"
}
EOF
)
  
  curl -sf -X POST "$API_URL/core/applications/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$app_payload" > /dev/null
  
  log_info "  Application created: $name"
  
  return 0
}

# ===================================================================
# Service configurations
# ===================================================================

SERVICES=(
  "grafana:Grafana Monitoring"
  "grafana"
  "https://grafana.${DOMAIN}/login/generic_oauth"
  "GRAFANA_OAUTH_CLIENT_ID"
  "GRAFANA_OAUTH_CLIENT_SECRET"
)
create_oidc_provider "Gitea: Git Hosting" \
  "gitea"
  "https://git.${DOMAIN}/user/oauth2/redirect"
  "GITEA_OAUTH_CLIENT_ID"
  "GITEA_OAUTH_CLIENT_SECRET"
)
create_oidc_provider "Outline: Knowledge Base" \
  "outline"
  "https://outline.${DOMAIN}/auth/oidc/callback"
  "OUTLINE_OAUTH_CLIENT_ID"
  "OUTLINE_OAUTH_CLIENT_SECRET"
)
create_oidc_provider "Portainer: Container Management" \
  "portainer"
  "https://portainer.${DOMAIN}/"
  "PORTAINER_OAUTH_CLIENT_ID"
  "PORTAINER_OAUTH_CLIENT_SECRET"
)
create_oidc_provider "Nextcloud: Cloud Storage" \
  "nextcloud"
  "https://nextcloud.${DOMAIN}/apps/sociallogin/oidc/authentik"
  "NEXTCLOUD_OAUTH_CLIENT_ID"
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"
)
create_oidc_provider "Open WebUI: AI Interface" \
  "open-webui"
  "https://ai.${DOMAIN}/oauth/oidc/callback"
  "OPEN_WEBUI_OAUTH_CLIENT_ID"
  "OPEN_WEBUI_OAUTH_CLIENT_SECRET"
)

log_step "All OIDC providers created successfully!"
log_info ""
log_info "Next steps:"
log_info "  1. Restart all dependent stacks to apply OIDC:"
log_info "     docker compose -f stacks/monitoring/docker-compose.yml restart grafana"
log_info "     docker compose -f stacks/productivity/docker-compose.yml restart gitea outline"
log_info "     docker compose -f stacks/base/docker-compose.yml restart portainer"
log_info "  2. Test login to each service using Authentik credentials"
log_info "  3. Verify user group permissions in Authentik admin UI"
log_info ""
log_info "Documentation: https://github.com/illbnm/homelab-stack/blob/master/docs/sso-integration.md"

exit 0

