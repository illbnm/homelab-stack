#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers, applications, and user groups.
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${DIM}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_error "Generate one: openssl rand -hex 32"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

api_get() { curl -sf "$1" -H "$AUTH_HEADER"; }
api_post() { curl -sf -X POST "$1" -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$2"; }

get_default_flow() {
  api_get "$API_URL/flows/instances/?designation=${1}&ordering=slug" | jq -r '.results[0].pk'
}

get_signing_key() {
  api_get "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" | jq -r '.results[0].pk'
}

create_oidc_provider() {
  local name="$1" redirect_uri="$2" client_id_var="$3" client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)

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

  if $DRY_RUN; then
    log_dry "  Would create provider: $name"
    log_dry "  Redirect URI: $redirect_uri"
    log_dry "  Client ID var: $client_id_var"
    log_dry "  Client Secret var: $client_secret_var"
    return
  fi

  local response
  response=$(api_post "$API_URL/providers/oauth2/" "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  log_info "  Client ID:   $client_id"
  log_info "  Client Secret: $client_secret"

  # Write credentials to .env
  if [ -f "$ROOT_DIR/.env" ]; then
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
  fi

  # Create application
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk}')

  api_post "$API_URL/core/applications/" "$app_payload" > /dev/null

  log_info "  Application created: $name (slug: $slug)"
}

create_group() {
  local name="$1" parent="$2:-"

  if $DRY_RUN; then
    log_dry "Would create group: $name (parent: ${parent:-none})"
    return
  fi

  local payload
  payload=$(jq -n --arg name "$name" '{name: $name}')
  [ -n "$parent" ] && payload=$(echo "$payload" | jq --arg p "$parent" '. + {parent: $p}')

  local response
  response=$(api_post "$API_URL/core/groups/" "$payload")
  local pk
  pk=$(echo "$response" | jq -r '.pk')
  log_info "  Group created: $name (pk: $pk)"
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
log_step "Waiting for Authentik API..."
for i in $(seq 1 30); do
  if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>&1; then
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
# Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups"
create_group "homelab-admins"
create_group "homelab-users"
create_group "media-users"

# ------------------------------------------------------------------
# Create OIDC providers
# ------------------------------------------------------------------
log_step "Creating OIDC providers"

create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Open WebUI" \
  "https://openwebui.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo
if $DRY_RUN; then
  log_info "Dry-run complete. No changes were made."
else
  log_step "All providers and groups created successfully!"
  log_info "Credentials written to .env"
fi
log_info "Authentik admin: $AUTHENTIK_URL/if/admin/"
log_info "OIDC issuer:    $AUTHENTIK_URL/application/o/<slug>/"
