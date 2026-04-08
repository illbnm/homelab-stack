#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script (Enhanced for Bounty #9)
# Creates OIDC providers, applications, and user groups for all services
# Requires: curl, jq
# Usage: ./scripts/authentik-setup.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Parse arguments
DRY_RUN=false
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Usage: $0 [--dry-run]"
      exit 1
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
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

# Dry run mode functions
if [ "$DRY_RUN" = true ]; then
  log_info "🔍 DRY-RUN MODE: No changes will be made"
  exec() { log_dry "Would execute: $*"; }
  curl() { log_dry "Would curl: $*"; }
  sed() { log_dry "Would sed: $*"; }
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
    -H "$AUTH_HEADER" | jq -r '.results[0].pk' 2>/dev/null || echo ""
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk' 2>/dev/null || echo ""
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create OIDC provider: $name"
    log_dry "  Redirect URI: $redirect_uri"
    log_dry "  Client ID var: $client_id_var"
    log_dry "  Client Secret var: $client_secret_var"
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  
  if [ -z "$flow_pk" ] || [ -z "$signing_key" ]; then
    log_error "Failed to get required Authentik resources for $name"
    return 1
  fi

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

  # Update .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    sed -i.bak "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i.bak "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
    log_info "  Updated .env with credentials"
  fi

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

create_user_group() {
  local name="$1"
  local description="$2"

  log_step "Creating user group: $name"

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create user group: $name"
    return
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    '{name: $name, description: $description}')

  curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null

  log_info "  User group created: $name"
}

# Provider configuration matrix
PROVIDERS=(
  "Grafana;https://grafana.${DOMAIN}/login/generic_oauth;GRAFANA_OAUTH_CLIENT_ID;GRAFANA_OAUTH_CLIENT_SECRET"
  "Gitea;https://git.${DOMAIN}/user/oauth2/Authentik/callback;GITEA_OAUTH_CLIENT_ID;GITEA_OAUTH_CLIENT_SECRET"
  "Nextcloud;https://nextcloud.${DOMAIN}/apps/social_login/oidc/callback;NEXTCLOUD_OAUTH_CLIENT_ID;NEXTCLOUD_OAUTH_CLIENT_SECRET"
  "Outline;https://outline.${DOMAIN}/auth/oidc.callback;OUTLINE_OAUTH_CLIENT_ID;OUTLINE_OAUTH_CLIENT_SECRET"
  "Open WebUI;https://openwebui.${DOMAIN}/oauth/callback;OPENWEBUI_OAUTH_CLIENT_ID;OPENWEBUI_OAUTH_CLIENT_SECRET"
  "Portainer;https://portainer.${DOMAIN}/;PORTAINER_OAUTH_CLIENT_ID;PORTAINER_OAUTH_CLIENT_SECRET"
)

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
log_step "Waiting for Authentik API..."
if [ "$DRY_RUN" = false ]; then
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
else
  log_dry "Would wait for Authentik API to be ready"
fi

# ------------------------------------------------------------------
# Create OIDC providers
# ------------------------------------------------------------------
log_step "Creating OIDC Providers and Applications"
for provider in "${PROVIDERS[@]}"; do
  IFS=';' read -r name redirect_uri client_id_var client_secret_var <<< "$provider"
  create_oidc_provider "$name" "$redirect_uri" "$client_id_var" "$client_secret_var"
done

# ------------------------------------------------------------------
# Create user groups
# ------------------------------------------------------------------
log_step "Creating User Groups"
create_user_group "homelab-admins" "Full access to all services"
create_user_group "homelab-users" "Access to regular services"
create_user_group "media-users" "Access to media services only"

# ------------------------------------------------------------------
# Update .env with new variables if not present
# ------------------------------------------------------------------
if [ "$DRY_RUN" = false ] && [ -f "$ROOT_DIR/.env" ]; then
  log_step "Updating .env with new variables"
  
  # Add new OAuth client variables if not present
  for provider in "${PROVIDERS[@]}"; do
    IFS=';' read -r name redirect_uri client_id_var client_secret_var <<< "$provider"
    if ! grep -q "^${client_id_var}=" "$ROOT_DIR/.env"; then
      echo "${client_id_var}=" >> "$ROOT_DIR/.env"
    fi
    if ! grep -q "^${client_secret_var}=" "$ROOT_DIR/.env"; then
      echo "${client_secret_var}=" >> "$ROOT_DIR/.env"
    fi
  done
  
  # Add user group variables
  if ! grep -q "^AUTHENTIK_ADMIN_GROUP=" "$ROOT_DIR/.env"; then
    echo "AUTHENTIK_ADMIN_GROUP=homelab-admins" >> "$ROOT_DIR/.env"
  fi
  
  log_info "Updated .env with new OAuth variables"
fi

# ------------------------------------------------------------------
# Display summary
# ------------------------------------------------------------------
log_step "Setup Complete"
if [ "$DRY_RUN" = false ]; then
  log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/"
  log_info "Authentik URL: $AUTHENTIK_URL"
  log_info "Admin credentials: See .env file or Authentik initial setup"
else
  log_dry "Would show setup summary"
fi