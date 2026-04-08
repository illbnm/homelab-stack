#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services and manages user groups
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh          # Full setup
#   ./scripts/setup-authentik.sh --dry-run # Preview only
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY-RUN] Preview mode - no changes will be made"
fi

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_info "Get token from: Authentik UI → Directory → Tokens → Create Token"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

# -----------------------------------------------------------------------------
# Create OIDC Provider
# -----------------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

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

  if [ "$DRY_RUN" = true ]; then
    log_dry "  Would create provider: $name"
    log_dry "  Would use redirect_uri: $redirect_uri"
    return
  fi

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

  # Update .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    if grep -q "^${client_id_var}=" "$ROOT_DIR/.env"; then
      sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    else
      echo "${client_id_var}=${client_id}" >> "$ROOT_DIR/.env"
    fi

    if grep -q "^${client_secret_var}=" "$ROOT_DIR/.env"; then
      sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
    else
      echo "${client_secret_var}=${client_secret}" >> "$ROOT_DIR/.env"
    fi
  fi

  # Create Application
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

# -----------------------------------------------------------------------------
# Create User Groups
# -----------------------------------------------------------------------------
create_user_groups() {
  log_step "Creating user groups"

  local groups=("homelab-admins" "homelab-users" "media-users")

  for group in "${groups[@]}"; do
    if [ "$DRY_RUN" = true ]; then
      log_dry "  Would create group: $group"
      continue
    fi

    # Check if group exists
    local existing
    existing=$(curl -sf "$API_URL/core/groups/?slug=${group}" -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty')

    if [ -n "$existing" ]; then
      log_info "  Group already exists: $group"
    else
      local payload
      payload=$(jq -n --arg name "$group" --arg slug "$group" '{name: $name, slug: $slug}')

      curl -sf -X POST "$API_URL/core/groups/" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null

      log_info "  Created group: $group"
    fi
  done

  log_info "User groups ready"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
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

echo
log_step "Creating OIDC Providers"

# Create providers for all services
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
  "https://docs.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/oauth/redirect" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "OpenWebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPEN_WEBUI_OAUTH_CLIENT_ID" \
  "OPEN_WEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://cloud.${DOMAIN}/apps/oidc_login/oidc" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Bookstack" \
  "https://wiki.${DOMAIN}/login/oidc/Authentik/callback" \
  "BOOKSTACK_OAUTH_CLIENT_ID" \
  "BOOKSTACK_OAUTH_CLIENT_SECRET"

# Create user groups
create_user_groups

log_step "Setup complete!"
log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/"
log_info "Web UI: $AUTHENTIK_URL"
log_info ""
log_info "Next steps:"
log_info "  1. Configure services with OAuth credentials from .env"
log_info "  2. Restart services: docker compose -f stacks/xxx/docker-compose.yml restart"
log_info "  3. Test SSO login at each service"