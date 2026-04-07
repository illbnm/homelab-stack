#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services + user groups
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
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

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
DRY_RUN="${1:-}"

if [ -z "$TOKEN" ] && [ "$DRY_RUN" != "--dry-run" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

create_user_group() {
  local name="$1"
  local description="$2"

  log_step "Creating user group: $name"

  if [ "$DRY_RUN" = "--dry-run" ]; then
    log_info "  [DRY RUN] Would create group: $name"
    return 0
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    '{name: $name, attributes: {"description": $desc}}')

  local response
  response=$(curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1) || {
    if echo "$response" | grep -q "already exists"; then
      log_info "  Group already exists: $name"
    else
      log_error "  Failed to create group: $response"
    fi
    return 0
  }

  log_info "  Group created: $name"
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  if [ "$DRY_RUN" = "--dry-run" ]; then
    log_info "  [DRY RUN] Would create provider: $name"
    log_info "  [DRY RUN] Client ID: <will be generated>"
    log_info "  [DRY RUN] Redirect URI: $redirect_uri"
    return 0
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --arg uri "$redirect_uri" \
    --arg key "$signing_key" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $uri,
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      signing_key: $key
    }')

  local response
  response=$(curl -sf -X POST "$API_URL/providers/oauth2/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"
  log_info "  Client Secret: ${client_secret:0:10}..."
  log_info "  Redirect URI: $redirect_uri"

  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"

  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk}')

  curl -sf -X POST "$API_URL/core/applications/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$app_payload" > /dev/null

  log_info "  ✓ Application created: $name"
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
if [ "$DRY_RUN" != "--dry-run" ]; then
  log_step "Waiting for Authentik API..."
  for i in $(seq 1 30); do
    if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null; then
      log_info "Authentik is ready"
      break
    fi
    if [ "$i" -eq 30 ]; then
      log_error "Authentik did not become ready in 150s"
      exit 1
    fi
    echo -n "."
    sleep 5
  done
fi

# ------------------------------------------------------------------
# Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups..."

create_user_group "homelab-admins" "Full access to all services including admin interfaces"
create_user_group "homelab-users" "Access to standard services (Grafana, Gitea, Outline, etc.)"
create_user_group "media-users" "Access only to media services (Jellyfin, Jellyseerr)"

# ------------------------------------------------------------------
# Create OIDC/OAuth2 providers
# ------------------------------------------------------------------
log_step "Creating OIDC providers..."

# Grafana
create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

# Gitea
create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

# Nextcloud
create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

# Outline
create_oidc_provider \
  "Outline" \
  "https://docs.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

# Portainer
create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# Open WebUI
create_oidc_provider \
  "Open WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# Perplexica
create_oidc_provider \
  "Perplexica" \
  "https://search.${DOMAIN}/api/auth/callback/oidc" \
  "PERPLEXICA_OAUTH_CLIENT_ID" \
  "PERPLEXICA_OAUTH_CLIENT_SECRET"

log_step "✓ All providers created successfully"
log_info "OIDC Issuer: $AUTHENTIK_URL/application/o/<slug>/"
log_info "Credentials saved to: $ROOT_DIR/.env"

if [ "$DRY_RUN" = "--dry-run" ]; then
  log_warn "This was a DRY RUN. No changes were made."
  log_info "Run without --dry-run to apply changes."
fi
