#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services and sets up user groups
# Requires: curl, jq
# Usage: 
#   ./scripts/setup-authentik.sh          # Create all providers
#   ./scripts/setup-authentik.sh --dry-run  # Preview without creating
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
  esac
done

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

if [ "$DRY_RUN" = true ]; then
  log_warn "DRY RUN MODE - No changes will be made"
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
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

# ------------------------------------------------------------------
# Create OIDC Provider
# ------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  if [ "$DRY_RUN" = true ]; then
    log_info "  [DRY RUN] Would create provider: $name"
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
  log_info "  Client Secret: $client_secret"
  log_info "  Redirect URI: $redirect_uri"

  # Write to .env file
  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env" 2>/dev/null || true
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env" 2>/dev/null || true

  # Create application in Authentik
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

  log_info "  Application created: $name"
}

# ------------------------------------------------------------------
# Create User Groups
# ------------------------------------------------------------------
create_user_groups() {
  log_step "Creating user groups..."

  if [ "$DRY_RUN" = true ]; then
    log_info "  [DRY RUN] Would create groups: homelab-admins, homelab-users, media-users"
    return 0
  fi

  local groups=("homelab-admins" "homelab-users" "media-users")

  for group in "${groups[@]}"; do
    local payload
    payload=$(jq -n \
      --arg name "$group" \
      --arg slug "$group" \
      '{name: $name, slug: $slug}')

    local response
    response=$(curl -sf -X POST "$API_URL/core/groups/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$payload")

    if [ "$response" = "{}" ] || [ -n "$(echo "$response" | jq -r '.pk' 2>/dev/null)" ]; then
      log_info "  [OK] Created group: $group"
    else
      log_warn "  [SKIP] Group already exists: $group"
    fi
  done
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Create User Groups
# ------------------------------------------------------------------
create_user_groups

# ------------------------------------------------------------------
# Create OIDC Providers
# ------------------------------------------------------------------
log_step "Creating OIDC providers for all services..."

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
  "OpenWebUI" \
  "https://ai.${DOMAIN}/auth/callback/oidc" \
  "OPEN_WEBUI_OAUTH_CLIENT_ID" \
  "OPEN_WEBUI_OAUTH_CLIENT_SECRET"

# Nextcloud (uses OIDC callback path)
create_oidc_provider \
  "Nextcloud" \
  "https://cloud.${DOMAIN}/apps/oidc_login/callback" \
  "NEXTCLOUD_OIDC_CLIENT_ID" \
  "NEXTCLOUD_OIDC_CLIENT_SECRET"

# BookStack
create_oidc_provider \
  "BookStack" \
  "https://wiki.${DOMAIN}/login/oidc" \
  "BOOKSTACK_OIDC_CLIENT_ID" \
  "BOOKSTACK_OIDC_CLIENT_SECRET"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
log_step "Setup Complete!"
log_info "Authentik Admin UI: $AUTHENTIK_URL/if/admin/"
log_info ""
log_info "OIDC Provider URLs:"
log_info "  Grafana:     $AUTHENTIK_URL/application/o/grafana/"
log_info "  Gitea:       $AUTHENTIK_URL/application/o/gitea/"
log_info "  Outline:     $AUTHENTIK_URL/application/o/outline/"
log_info "  Portainer:   $AUTHENTIK_URL/application/o/portainer/"
log_info "  OpenWebUI:   $AUTHENTIK_URL/application/o/openwebui/"
log_info "  Nextcloud:   $AUTHENTIK_URL/application/o/nextcloud/"
log_info "  BookStack:   $AUTHENTIK_URL/application/o/bookstack/"
log_info ""
log_info "Credentials have been written to .env"
log_info "Restart services to apply new OIDC settings"