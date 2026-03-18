#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Setup Script
# Creates OIDC providers, applications, and user groups for all homelab services
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Parse flags
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run  Preview what would be created without making changes"
      exit 0
      ;;
  esac
done

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  echo "  Generate a token in Authentik Admin → Directory → Tokens"
  echo "  Then add to .env: AUTHENTIK_BOOTSTRAP_TOKEN=your-token"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"
CREATED_COUNT=0
SKIPPED_COUNT=0

# ─── Helper Functions ────────────────────────────────────────────────────────

api_get() {
  curl -sf "$API_URL/$1" -H "$AUTH_HEADER"
}

api_post() {
  curl -sf -X POST "$API_URL/$1" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$2"
}

get_default_flow() {
  local designation="$1"
  api_get "flows/instances/?designation=${designation}&ordering=slug" | jq -r '.results[0].pk'
}

get_signing_key() {
  api_get "crypto/certificatekeypairs/?has_key=true&ordering=name" | jq -r '.results[0].pk'
}

check_provider_exists() {
  local name="$1"
  local count
  count=$(api_get "providers/oauth2/?search=${name}" | jq -r '.pagination.count')
  [ "$count" -gt 0 ]
}

# ─── Create User Group ──────────────────────────────────────────────────────

create_group() {
  local name="$1"
  local is_superuser="${2:-false}"

  if $DRY_RUN; then
    log_dry "Would create group: $name (superuser=$is_superuser)"
    return
  fi

  # Check if group already exists
  local existing
  existing=$(api_get "core/groups/?search=${name}" | jq -r '.pagination.count')
  if [ "$existing" -gt 0 ]; then
    log_warn "Group already exists: $name"
    return
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --argjson su "$is_superuser" \
    '{name: $name, is_superuser: $su}')

  api_post "core/groups/" "$payload" > /dev/null
  log_info "Created group: $name"
}

# ─── Create OIDC Provider + Application ──────────────────────────────────────

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Provider: $name"

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  if $DRY_RUN; then
    log_dry "Would create OIDC provider: $name"
    log_dry "  Redirect URI: $redirect_uri"
    log_dry "  Client ID var:     $client_id_var"
    log_dry "  Client Secret var: $client_secret_var"
    log_dry "  OIDC issuer: $AUTHENTIK_URL/application/o/${slug}/"
    return
  fi

  # Check if provider already exists
  if check_provider_exists "$name"; then
    log_warn "Provider already exists: $name (skipping)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorization)
  signing_key=$(get_signing_key)

  if [ "$flow_pk" = "null" ] || [ -z "$flow_pk" ]; then
    log_error "No authorization flow found. Is Authentik fully initialized?"
    return
  fi

  local payload
  payload=$(jq -n \
    --arg name "${name}" \
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
      property_mappings: [],
      access_code_validity: "minutes=1",
      access_token_validity: "minutes=5",
      refresh_token_validity: "days=30"
    }')

  local response
  response=$(api_post "providers/oauth2/" "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  if [ "$provider_pk" = "null" ] || [ -z "$provider_pk" ]; then
    log_error "Failed to create provider: $name"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    return
  fi

  log_info "Created provider: $name"
  echo "     Client ID:     $client_id"
  echo "     Client Secret: $client_secret"
  echo "     Redirect URI:  $redirect_uri"

  # Update .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    sed -i'' "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i'' "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
    log_info "Credentials written to .env ($client_id_var, $client_secret_var)"
  fi

  # Create application
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{
      name: $name,
      slug: $slug,
      provider: $pk,
      meta_launch_url: "",
      open_in_new_tab: true
    }')

  api_post "core/applications/" "$app_payload" > /dev/null
  log_info "Created application: $name"
  CREATED_COUNT=$((CREATED_COUNT + 1))
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Authentik SSO Setup — HomeLab Stack"
echo "  URL: ${AUTHENTIK_URL}"
if $DRY_RUN; then
  echo "  Mode: DRY RUN (no changes will be made)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Wait for Authentik ──────────────────────────────────────────────────────
if ! $DRY_RUN; then
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

# ─── Create User Groups ─────────────────────────────────────────────────────
log_step "Creating user groups..."
create_group "homelab-admins" true
create_group "homelab-users" false
create_group "media-users" false

# ─── Create OIDC Providers ──────────────────────────────────────────────────

# Grafana — Monitoring dashboards
create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET"

# Gitea — Git hosting
create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET"

# Outline — Knowledge base
create_oidc_provider \
  "Outline" \
  "https://docs.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

# Portainer — Container management
create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# Nextcloud — File storage & collaboration
create_oidc_provider \
  "Nextcloud" \
  "https://cloud.${DOMAIN}/apps/oidc_login/oidc" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

# Open WebUI — AI chat interface
create_oidc_provider \
  "Open-WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# ─── Summary ────────────────────────────────────────────────────────────────
log_step "Setup Complete"
if $DRY_RUN; then
  echo "  Dry run finished. No changes were made."
  echo "  Run without --dry-run to execute."
else
  echo "  Created: ${CREATED_COUNT} providers"
  echo "  Skipped: ${SKIPPED_COUNT} providers (already exist)"
  echo ""
  echo "  Next steps:"
  echo "  1. Restart services to pick up new OAuth credentials:"
  echo "     cd stacks/monitoring && docker compose up -d grafana"
  echo "     cd stacks/productivity && docker compose up -d gitea outline"
  echo "     cd stacks/ai && docker compose up -d open-webui"
  echo ""
  echo "  2. Set up Nextcloud OIDC:"
  echo "     ./scripts/nextcloud-oidc-setup.sh"
  echo ""
  echo "  3. OIDC Issuer URLs:"
  echo "     Grafana:    $AUTHENTIK_URL/application/o/grafana/"
  echo "     Gitea:      $AUTHENTIK_URL/application/o/gitea/"
  echo "     Outline:    $AUTHENTIK_URL/application/o/outline/"
  echo "     Portainer:  $AUTHENTIK_URL/application/o/portainer/"
  echo "     Nextcloud:  $AUTHENTIK_URL/application/o/nextcloud/"
  echo "     Open WebUI: $AUTHENTIK_URL/application/o/open-webui/"
fi
