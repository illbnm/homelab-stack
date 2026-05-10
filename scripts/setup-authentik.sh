#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers, user groups, and application bindings.
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh           # Full setup
#   ./scripts/setup-authentik.sh --dry-run  # Preview only
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
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log_info "Running in DRY-RUN mode — no changes will be made"
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL:-admin@${DOMAIN}}"
BOOTSTRAP_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD:-}"

if [ -z "$TOKEN" ] && [ "$DRY_RUN" = false ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_error "Run: echo \"AUTHENTIK_BOOTSTRAP_TOKEN=\$(openssl rand -hex 32)\" >> .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

api_call() {
  local method="$1" url="$2" data="$3"
  if [ "$DRY_RUN" = true ]; then
    echo '{"pk":0,"client_id":"DRY_RUN_CLIENT_ID","client_secret":"DRY_RUN_CLIENT_SECRET"}'
    return
  fi
  curl -sf -X "$method" "$url" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$data"
}

create_group() {
  local name="$1"
  log_info "  Creating group: $name"
  if [ "$DRY_RUN" = true ]; then
    log_dry "    Would create group '$name'"
    return
  fi
  local exists
  exists=$(curl -sf "$API_URL/core/groups/?name=${name}" -H "$AUTH_HEADER" | jq -r '.results | length')
  if [ "$exists" -gt 0 ]; then
    log_info "    Group '$name' already exists, skipping"
    return
  fi
  api_call POST "$API_URL/core/groups/" "$(jq -n --arg name "$name" '{name: $name}')" > /dev/null
  log_info "    Group '$name' created"
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  if [ "$DRY_RUN" = true ]; then
    local slug
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    log_dry "  Would create provider '$name' with redirect: $redirect_uri"
    log_dry "  Would write ${client_id_var}=<generated> to .env"
    log_dry "  Would write ${client_secret_var}=<generated> to .env"
    log_dry "  Would create application '$name'"
    log_dry "  OIDC issuer URL: $AUTHENTIK_URL/application/o/${slug}/"
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Check if provider already exists (by name)
  local existing
  existing=$(curl -sf "$API_URL/providers/oauth2/?search=${name}" -H "$AUTH_HEADER" | jq -r '.results | length')
  if [ "$existing" -gt 0 ]; then
    log_warn "  Provider '$name' already exists, fetching existing credentials"
    local existing_id existing_client_id
    existing_id=$(curl -sf "$API_URL/providers/oauth2/?search=${name}" -H "$AUTH_HEADER" | jq -r '.results[0].client_id')
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${existing_id}|" "$ROOT_DIR/.env"
    log_info "  Client ID:   $existing_id"
    log_info "  OIDC issuer: $AUTHENTIK_URL/application/o/${slug}/"
    return
  fi

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
  response=$(api_call POST "$API_URL/providers/oauth2/" "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"

  # Write credentials to .env
  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"

  # Create application
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk}')

  api_call POST "$API_URL/core/applications/" "$app_payload" > /dev/null
  log_info "  Application created: $name"
  log_info "  OIDC issuer URL: $AUTHENTIK_URL/application/o/${slug}/"
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
if [ "$DRY_RUN" = false ]; then
  log_step "Waiting for Authentik API..."
  for i in $(seq 1 30); do
    if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>/dev/null; then
      log_info "Authentik is ready"
      break
    fi
    if [ "$i" -eq 30 ]; then
      log_error "Authentik did not become ready in 150s"
      log_error "Check: docker compose -f stacks/sso/docker-compose.yml ps"
      exit 1
    fi
    echo -n "."
    sleep 5
  done
else
  log_info "Skipping health check (--dry-run)"
fi

# ------------------------------------------------------------------
# Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups"

create_group "homelab-admins"
create_group "homelab-users"
create_group "media-users"

if [ "$DRY_RUN" = false ]; then
  log_info "Group hierarchy:"
  log_info "  homelab-admins  → Full access to all admin interfaces"
  log_info "  homelab-users   → Access to standard services"
  log_info "  media-users     → Access to Jellyfin/Jellyseerr only"
fi

# ------------------------------------------------------------------
# Create OIDC providers for all services
# ------------------------------------------------------------------
log_step "Creating OIDC providers"

# Monitoring
create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

# Productivity
create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

# Base
create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# AI
create_oidc_provider \
  "Open WebUI" \
  "https://openwebui.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
log_step "Setup complete!"
echo ""
echo -e "  ${BOLD}Authentik Admin UI:${RESET}  ${AUTHENTIK_URL}/if/admin/"
echo -e "  ${BOLD}User Portal:${RESET}         ${AUTHENTIK_URL}/if/user/"
echo ""
echo "  All credentials written to ${ROOT_DIR}/.env"
echo ""
echo "  Next steps:"
echo "  1. Restart services to pick up new OAuth credentials"
echo "  2. Log in to Authentik admin and assign users to groups"
echo "  3. Test SSO login on each service"

if [ "$DRY_RUN" = true ]; then
  echo ""
  log_info "This was a dry run. Run without --dry-run to apply changes."
fi
