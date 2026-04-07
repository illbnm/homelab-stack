#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC/OAuth2 providers and user groups for all services
# Usage: ./scripts/authentik-setup.sh [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Parse command line arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
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

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# Dry run function
dry_run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "[DRY RUN] $*"
    return 0
  else
    eval "$*"
    return $?
  fi
}

get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

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
  response=$(dry_run "curl -sf -X POST \"$API_URL/providers/oauth2/\" \
    -H \"$AUTH_HEADER\" \
    -H \"Content-Type: application/json\" \
    -d \"$payload\"")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"

  dry_run "sed -i \"s|^${client_id_var}=.*|${client_id_var}=${client_id}|\" \"$ROOT_DIR/.env\""
  dry_run "sed -i \"s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|\" \"$ROOT_DIR/.env\""

  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{name: $name, slug: $slug, provider: $pk}')

  dry_run "curl -sf -X POST \"$API_URL/core/applications/\" \
    -H \"$AUTH_HEADER\" \
    -H \"Content-Type: application/json\" \
    -d \"$app_payload\" > /dev/null"

  log_info "  Application created: $name"
}

create_user_group() {
  local name="$1"
  local description="$2"
  local attributes="$3"

  log_step "Creating user group: $name"

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --argjson attributes "$attributes" \
    '{
      name: $name,
      description: $description,
      attributes: $attributes
    }')

  local response
  response=$(dry_run "curl -sf -X POST \"$API_URL/core/groups/\" \
    -H \"$AUTH_HEADER\" \
    -H \"Content-Type: application/json\" \
    -d \"$payload\"")

  local group_pk
  group_pk=$(echo "$response" | jq -r '.pk')
  log_info "  User group created: $name (PK: $group_pk)"
}

create_policy() {
  local name="$1"
  local local_policy_type="$2"
  local description="$3"
  local target="$4"

  log_step "Creating policy: $name"

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg policy_type "$local_policy_type" \
    --arg description "$description" \
    --argjson target "$target" \
    '{
      name: $name,
      policy_type: $policy_type,
      description: $description,
      target: $target
    }')

  local response
  response=$(dry_run "curl -sf -X POST \"$API_URL/policies/default/\" \
    -H \"$AUTH_HEADER\" \
    -H \"Content-Type: application/json\" \
    -d \"$payload\"")

  local policy_pk
  policy_pk=$(echo "$response" | jq -r '.pk')
  log_info "  Policy created: $name (PK: $policy_pk)"
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
# Create OIDC providers
# ------------------------------------------------------------------
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
  "Portainer" \
  "https://portainer.${DOMAIN}/oauth2/callback" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups..."

create_user_group \
  "homelab-admins" \
  "Full access to all services" \
  '{"permissions": "admin"}'

create_user_group \
  "homelab-users" \
  "Access to regular services" \
  '{"permissions": "user"}'

create_user_group \
  "media-users" \
  "Media services only (Jellyfin, Jellyseerr)" \
  '{"permissions": "media"}'

# ------------------------------------------------------------------
# Create policies for group access control
# ------------------------------------------------------------------
log_step "Creating access policies..."

# Policy for homelab-admins - full access
create_policy \
  "admin-full-access" \
  "access_control" \
  "Full access for homelab-admins group" \
  '{"users": "homelab-admins"}'

# Policy for homelab-users - regular service access
create_policy \
  "user-regular-access" \
  "access_control" \
  "Regular service access for homelab-users group" \
  '{"users": "homelab-users"}'

# Policy for media-users - media services only
create_policy \
  "media-service-access" \
  "access_control" \
  "Media services only for media-users group" \
  '{"users": "media-users"}'

log_step "All providers and user groups created."
log_info "Client IDs and secrets written to .env"
log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/<slug>/"
log_info "User groups created: homelab-admins, homelab-users, media-users"

if [[ "$DRY_RUN" == "true" ]]; then
  log_step "DRY RUN COMPLETE - No changes made"
else
  log_step "✅ Authentik SSO setup completed successfully!"
fi