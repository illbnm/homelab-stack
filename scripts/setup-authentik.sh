#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services and outputs credentials
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
DRY_RUN=false

# Parse arguments
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  echo "[DRY RUN] No changes will be made"
fi

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo "[ERROR] .env file not found. Run: cp .env.example .env"
  exit 1
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
log_skip()  { echo -e "${YELLOW}[SKIP]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

# Check required environment variables
if [ -z "${DOMAIN:-}" ]; then
  log_error "DOMAIN is not set in .env"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_info "To create a token:"
  log_info "  1. Login to Authentik: $AUTHENTIK_URL"
  log_info "  2. Go to Admin → Directory → Tokens"
  log_info "  3. Create a token with 'authentik-core' intent"
  log_info "  4. Add to .env: AUTHENTIK_BOOTSTRAP_TOKEN=your_token"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# API helper functions
api_get() {
  curl -sf "$1" -H "$AUTH_HEADER" 2>/dev/null
}

api_post() {
  local url="$1"
  local payload="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] POST $url"
    echo "Payload: $payload"
    return 0
  fi
  curl -sf -X POST "$url" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null
}

get_default_flow() {
  local designation="$1"
  api_get "$API_URL/flows/instances/?designation=${designation}&ordering=slug" | jq -r '.results[0].pk // empty'
}

get_signing_key() {
  api_get "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" | jq -r '.results[0].pk // empty'
}

# Create OIDC provider and application
create_oidc_provider() {
  local name="$1"
  local redirect_uris="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  log_step "Creating OIDC provider: $name"

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorization)
  signing_key=$(get_signing_key)

  if [ -z "$flow_pk" ]; then
    log_error "No authorization flow found"
    return 1
  fi

  # Build payload
  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --argjson uris "$redirect_uris" \
    --arg key "$signing_key" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $uris,
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      signing_key: ($key // null)
    }')

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create provider: $name"
    echo "  Redirect URIs: $redirect_uris"
    return 0
  fi

  local response
  response=$(api_post "$API_URL/providers/oauth2/" "$payload")

  if [ -z "$response" ]; then
    log_error "Failed to create provider: $name"
    return 1
  fi

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk // empty')
  client_id=$(echo "$response" | jq -r '.client_id // empty')
  client_secret=$(echo "$response" | jq -r '.client_secret // empty')

  if [ -z "$provider_pk" ]; then
    log_error "Failed to parse provider response"
    echo "Response: $response"
    return 1
  fi

  log_ok "Created provider: $name"
  echo "  Provider PK: $provider_pk"
  echo "  Client ID:   $client_id"
  echo "  Client Secret: $client_secret"

  # Update .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    # Remove old values if they exist
    sed -i "/^${client_id_var}=/d" "$ROOT_DIR/.env" 2>/dev/null || true
    sed -i "/^${client_secret_var}=/d" "$ROOT_DIR/.env" 2>/dev/null || true
    
    # Append new values
    echo "${client_id_var}=${client_id}" >> "$ROOT_DIR/.env"
    echo "${client_secret_var}=${client_secret}" >> "$ROOT_DIR/.env"
    log_info "  Credentials written to .env"
  fi

  # Create application
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk, policy_engine_mode: "any"}')

  local app_response
  app_response=$(api_post "$API_URL/core/applications/" "$app_payload")

  if [ -n "$app_response" ]; then
    log_ok "Created application: $name"
    echo "  Redirect URI: https://${slug}.${DOMAIN}"
  else
    log_warn "Failed to create application (may already exist)"
  fi

  echo ""
}

# Create user groups
create_groups() {
  log_step "Creating user groups"

  local groups='[
    {"name": "homelab-admins", "attributes": {"description": "Full access to all services"}},
    {"name": "homelab-users", "attributes": {"description": "Access to regular services"}},
    {"name": "media-users", "attributes": {"description": "Access to media services only"}}
  ]'

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create groups:"
    echo "$groups" | jq -r '.[] | "  - \(.name): \(.attributes.description)"'
    return 0
  fi

  echo "$groups" | jq -c '.[]' | while read -r group; do
    local name attributes
    name=$(echo "$group" | jq -r '.name')
    attributes=$(echo "$group" | jq -c '.attributes')
    
    local payload
    payload=$(jq -n --arg name "$name" --argjson attr "$attributes" \
      '{name: $name, attributes: $attr}')
    
    local response
    response=$(api_post "$API_URL/core/groups/" "$payload")
    
    if [ -n "$response" ]; then
      log_ok "Created group: $name"
    else
      log_warn "Group '$name' may already exist"
    fi
  done
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
log_step "Waiting for Authentik API..."
for i in $(seq 1 60); do
  if api_get "$AUTHENTIK_URL/-/health/ready/" > /dev/null 2>&1; then
    log_ok "Authentik is ready"
    break
  fi
  if [ "$i" -eq 60 ]; then
    log_error "Authentik did not become ready in 300s"
    log_info "Check logs: docker logs authentik-server"
    exit 1
  fi
  echo -n "."
  sleep 5
done
echo ""

# ------------------------------------------------------------------
# Create groups
# ------------------------------------------------------------------
create_groups

# ------------------------------------------------------------------
# Create OIDC Providers
# ------------------------------------------------------------------

# Grafana
create_oidc_provider \
  "Grafana" \
  "[\"https://grafana.${DOMAIN}/login/generic_oauth\"]" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

# Gitea
create_oidc_provider \
  "Gitea" \
  "[\"https://git.${DOMAIN}/user/oauth2/Authentik/callback\"]" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

# Outline
create_oidc_provider \
  "Outline" \
  "[\"https://docs.${DOMAIN}/auth/oidc.callback\"]" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

# BookStack
create_oidc_provider \
  "BookStack" \
  "[\"https://wiki.${DOMAIN}/oidc/callback\"]" \
  "BOOKSTACK_OIDC_CLIENT_ID" \
  "BOOKSTACK_OIDC_CLIENT_SECRET"

# Nextcloud
create_oidc_provider \
  "Nextcloud" \
  "[\"https://cloud.${DOMAIN}/apps/user_oidc/code\"]" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

# Open WebUI
create_oidc_provider \
  "Open-WebUI" \
  "[\"https://ai.${DOMAIN}/oauth/oidc/callback\"]" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# Portainer
create_oidc_provider \
  "Portainer" \
  "[\"https://portainer.${DOMAIN}/\"]" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
log_step "Setup Complete!"
echo ""
echo "OIDC Issuer URL: $AUTHENTIK_URL/application/o/"
echo ""
echo "Next steps:"
echo "  1. Restart affected services to pick up new credentials"
echo "  2. For Nextcloud: install 'user_oidc' app and configure"
echo "  3. For Gitea: configure OAuth via Admin → Authentication Sources"
echo "  4. For Portainer: configure via Settings → Authentication → OAuth"
echo ""
echo "Documentation: docs/SSO-INTEGRATION.md"