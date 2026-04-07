#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Complete Setup Script
# Creates OIDC/OAuth providers for ALL services + User Groups
# Requires: curl, jq
# Usage: ./scripts/authentik-setup.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
elif [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
else
  echo "ERROR: No .env file found"
  exit 1
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Dry run mode
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
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

# Store credentials for output
declare -A PROVIDER_CREDENTIALS

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

create_group() {
  local name="$1"
  local description="$2"

  log_step "Creating group: $name"

  if [ "$DRY_RUN" = true ]; then
    log_info "  [DRY RUN] Would create group: $name"
    return 0
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    '{name: $name, attributes: {description: $desc}}')

  local response
  response=$(curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload")

  log_info "  Group created: $name"
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local scopes="${5:-openid profile email}"

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
  slug=$(echo "$name" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-]//g')

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --arg uri "$redirect_uri" \
    --arg key "$signing_key" \
    --arg scopes "$scopes" \
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
  log_info "  Client Secret: ${client_secret:0:8}...${client_secret: -4}"

  # Store credentials
  PROVIDER_CREDENTIALS["$name"]="Client ID: $client_id\nClient Secret: $client_secret"

  # Update .env file
  local env_file="$ROOT_DIR/.env"
  if [ ! -f "$env_file" ]; then
    env_file="$ROOT_DIR/stacks/sso/.env"
  fi

  if grep -q "^${client_id_var}=" "$env_file" 2>/dev/null; then
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$env_file"
  else
    echo "${client_id_var}=${client_id}" >> "$env_file"
  fi

  if grep -q "^${client_secret_var}=" "$env_file" 2>/dev/null; then
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$env_file"
  else
    echo "${client_secret_var}=${client_secret}" >> "$env_file"
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

create_oauth_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OAuth provider: $name"

  if [ "$DRY_RUN" = true ]; then
    log_info "  [DRY RUN] Would create OAuth provider: $name"
    return 0
  fi

  # OAuth providers use same flow as OIDC but different configuration
  create_oidc_provider "$name" "$redirect_uri" "$client_id_var" "$client_secret_var"
}

# -----------------------------------------------------------------------------
# Wait for Authentik
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

# -----------------------------------------------------------------------------
# Create User Groups
# -----------------------------------------------------------------------------
log_step "Creating user groups..."

create_group "homelab-admins" "Full access to all services and admin panels"
create_group "homelab-users" "Access to standard user services"
create_group "media-users" "Access to media services only (Jellyfin, Jellyseerr)"

# -----------------------------------------------------------------------------
# Create OIDC Providers for All Services
# -----------------------------------------------------------------------------

# 1. Grafana
create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

# 2. Gitea
create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

# 3. Outline
create_oidc_provider \
  "Outline" \
  "https://docs.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

# 4. Nextcloud
create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

# 5. Open WebUI
create_oidc_provider \
  "Open WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# 6. Portainer (OAuth)
create_oauth_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log_step "Setup Complete!"

if [ "$DRY_RUN" = true ]; then
  log_warn "This was a DRY RUN - no changes were made"
  log_info "Run without --dry-run to apply changes"
else
  log_info "All providers created and credentials written to .env"
  echo
  log_info "Provider Credentials Summary:"
  echo "================================"
  for name in "${!PROVIDER_CREDENTIALS[@]}"; do
    echo -e "\n[$name]"
    echo -e "${PROVIDER_CREDENTIALS[$name]}"
  done

  echo
  log_info "Next Steps:"
  log_info "  1. Restart services to pick up new environment variables"
  log_info "  2. Run: cd stacks/productivity && docker compose restart gitea outline"
  log_info "  3. Run: cd stacks/storage && docker compose restart nextcloud"
  log_info "  4. Run: cd stacks/ai && docker compose restart open-webui"
  log_info "  5. Run: cd stacks/base && docker compose restart portainer"
  log_info "  6. Run: ./scripts/nextcloud-oidc-setup.sh (for Nextcloud OIDC setup)"
  log_info "  7. Test login to each service with Authentik credentials"
fi
