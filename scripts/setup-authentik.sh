#!/usr/bin/env bash
# =============================================================================
# Authentik SSO Setup — Enhanced version with user groups
# Creates OIDC providers + user groups for the entire homelab ecosystem
# Usage: ./scripts/setup-authentik.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY-RUN] Would perform the following actions:"
fi

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==>${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_info "Generate with: openssl rand -hex 32"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# =============================================================================
# Helper functions
# =============================================================================

api_get() {
  local endpoint="$1"
  curl -sf "${API_URL}${endpoint}" -H "$AUTH_HEADER"
}

api_post() {
  local endpoint="$1"; shift
  local payload="$1"
  curl -sf -X POST "${API_URL}${endpoint}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

get_pk() {
  local endpoint="$1"
  api_get "$endpoint" | jq -r '.results[0].pk // .pk // empty'
}

# =============================================================================
# Wait for Authentik to be ready
# =============================================================================
log_step "Waiting for Authentik API..."
for i in $(seq 1 30); do
  if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>&1; then
    log_ok "Authentik is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    log_error "Authentik did not become ready in 150s"
    exit 1
  fi
  echo -n "."
  sleep 5
done

# =============================================================================
# Create User Groups
# =============================================================================
log_step "Setting up user groups..."

GROUP_DEFINITIONS='[
  {"name": "homelab-admins", "slug": "homelab-admins", "description": "Full admin access to all services"},
  {"name": "homelab-users", "slug": "homelab-users", "description": "Standard user access"},
  {"name": "media-users", "slug": "media-users", "description": "Media-only access (Jellyfin/Jellyseerr)"}
]'

for group in $(echo "$GROUP_DEFINITIONS" | jq -c '.[]'); do
  name=$(echo "$group" | jq -r '.name')
  slug=$(echo "$group" | jq -r '.slug')
  description=$(echo "$group" | jq -r '.description')

  existing=$(api_get "/core/groups/?slug=${slug}" | jq -r '.results[0].pk // empty')
  if [ -n "$existing" ]; then
    log_ok "Group already exists: $name"
  else
    if [ "$DRY_RUN" == "true" ]; then
      echo "  [DRY-RUN] Would create group: $name"
    else
      payload=$(jq -n \
        --arg name "$name" \
        --arg slug "$slug" \
        --arg desc "$description" \
        '{name: $name, slug: $slug, attributes: {description: [$desc]}}')
      pk=$(api_post "/core/groups/" "$payload" | jq -r '.pk // empty')
      if [ -n "$pk" ]; then
        log_ok "Created group: $name (pk=$pk)"
      else
        log_warn "Could not create group: $name"
      fi
    fi
  fi
done

# =============================================================================
# Create OIDC Provider
# =============================================================================
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local extra_scopes="${5:-}"

  log_step "Creating OIDC provider: $name"

  # Check if provider already exists
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  local existing_pk
  existing_pk=$(api_get "/providers/oauth2/?search=${name}" | jq -r ".results[] | select(.name == \"${name} Provider\") | .pk // empty")
  
  if [ -n "$existing_pk" ]; then
    log_ok "Provider already exists: $name (pk=$existing_pk)"
    # Still write existing credentials to .env if needed
    local existing_data
    existing_data=$(api_get "/providers/oauth2/${existing_pk}/")
    local existing_client_id existing_client_secret
    existing_client_id=$(echo "$existing_data" | jq -r '.client_id // empty')
    existing_client_secret=$(echo "$existing_data" | jq -r '.client_secret // empty')
    if [ -n "$existing_client_id" ] && grep -q "^${client_id_var}=" "$ROOT_DIR/.env" 2>/dev/null; then
      sed -i "s|^${client_id_var}=.*|${client_id_var}=${existing_client_id}|" "$ROOT_DIR/.env"
      sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${existing_client_secret}|" "$ROOT_DIR/.env"
    fi
    return 0
  fi

  local flow_pk signing_key
  flow_pk=$(get_pk "/flows/instances/?designation=authorize")
  signing_key=$(get_pk "/crypto/certificatekeypairs/?has_key=true&ordering=name")

  if [ -z "$flow_pk" ] || [ -z "$signing_key" ]; then
    log_error "Could not get authorize flow or signing key"
    return 1
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
      signing_key: $key,
      extra_claims: {}
    }')

  if [ "$DRY_RUN" == "true" ]; then
    echo "  [DRY-RUN] Would create provider: $name"
    echo "  [DRY-RUN] Redirect URI: $redirect_uri"
    return 0
  fi

  local response
  response=$(api_post "/providers/oauth2/" "$payload")
  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk // empty')
  client_id=$(echo "$response" | jq -r '.client_id // empty')
  client_secret=$(echo "$response" | jq -r '.client_secret // empty')

  if [ -z "$provider_pk" ] || [ "$provider_pk" == "null" ]; then
    log_error "Failed to create provider: $name"
    log_error "Response: $response"
    return 1
  fi

  log_ok "  Provider PK: $provider_pk"
  log_ok "  Client ID:   $client_id"

  # Write credentials to .env
  if [ -f "$ROOT_DIR/.env" ]; then
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
  fi

  # Create Application in Authentik
  local app_slug
  app_slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$app_slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk}')
  api_post "/core/applications/" "$app_payload" > /dev/null
  log_ok "  Application created: $name"
}

# =============================================================================
# Create all providers
# =============================================================================
log_step "Creating OIDC Providers..."

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
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/oidc_login/oidc" \
  "NEXTCLOUD_OIDC_CLIENT_ID" \
  "NEXTCLOUD_OIDC_CLIENT_SECRET"

create_oidc_provider \
  "OpenWebUI" \
  "https://ai.${DOMAIN}/api/auth/oidc/authentik/callback" \
  "OPENWEBUI_OIDC_CLIENT_ID" \
  "OPENWEBUI_OIDC_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================================"
log_ok "All providers and groups created!"
echo "============================================================"
echo ""
echo "Credentials have been written to: $ROOT_DIR/.env"
echo ""
echo "Next steps:"
echo "  1. Update Grafana config:    GF_AUTH_GENERIC_OAUTH_* vars"
echo "  2. Update Gitea .env:       GITEA_OAUTH_CLIENT_ID/SECRET"
echo "  3. Update Outline .env:     OIDC_CLIENT_ID/SECRET"
echo "  4. Update Nextcloud .env:   NEXTCLOUD_OIDC_* vars"
echo "  5. Update AI stack .env:    OPENWEBUI_OIDC_* vars"
echo "  6. Update Portainer .env:   PORTAINER_OAUTH_* vars"
echo ""
echo "Authentik admin UI: $AUTHENTIK_URL/if/admin/"
echo "OIDC issuer: $AUTHENTIK_URL/application/o/<slug>/"
echo ""
