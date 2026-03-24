#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Setup Script
# Creates OIDC providers, applications, and user groups for all services.
#
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh              # Create all providers
#   ./scripts/setup-authentik.sh --dry-run    # Preview without changes
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--dry-run]

Options:
  --dry-run    Preview what would be created without making changes
  -h, --help   Show this help

This script uses the Authentik API to:
  1. Create OIDC providers for Grafana, Gitea, Outline, Portainer,
     Nextcloud, and Open WebUI
  2. Create corresponding Authentik applications
  3. Create user groups (homelab-admins, homelab-users, media-users)
  4. Write Client ID/Secret to .env

Requires AUTHENTIK_BOOTSTRAP_TOKEN to be set in .env.
EOF
      exit 0
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ---------------------------------------------------------------------------
# API Helpers
# ---------------------------------------------------------------------------
get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

# ---------------------------------------------------------------------------
# Create a user group
# ---------------------------------------------------------------------------
create_group() {
  local name="$1"
  local is_superuser="${2:-false}"

  if $DRY_RUN; then
    log_dry "Would create group: $name (superuser=$is_superuser)"
    return
  fi

  # Check if group already exists
  local existing
  existing=$(curl -sf "$API_URL/core/groups/?name=$name" \
    -H "$AUTH_HEADER" | jq -r '.results | length')

  if [ "$existing" -gt 0 ]; then
    log_info "Group already exists: $name"
    return
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --argjson su "$is_superuser" \
    '{name: $name, is_superuser: $su}')

  curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null

  log_info "Created group: $name"
}

# ---------------------------------------------------------------------------
# Create OIDC provider + application
# ---------------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  if $DRY_RUN; then
    log_dry "Provider:     $name"
    log_dry "Slug:         $slug"
    log_dry "Redirect URI: $redirect_uri"
    log_dry "Env vars:     $client_id_var / $client_secret_var"
    log_dry "Issuer URL:   $AUTHENTIK_URL/application/o/$slug/"
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorization)
  signing_key=$(get_signing_key)

  local payload
  payload=$(jq -n \
    --arg name "$name" \
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
  log_info "  Redirect URI: $redirect_uri"

  # Write credentials to .env
  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"

  # Create the corresponding application
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

# ===========================================================================
# Main
# ===========================================================================

if $DRY_RUN; then
  echo
  echo -e "${BOLD}${YELLOW}=== DRY RUN MODE — no changes will be made ===${RESET}"
fi

# ------------------------------------------------------------------
# Wait for Authentik to be ready (skip in dry-run)
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Step 1: Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups..."

create_group "homelab-admins" "true"
create_group "homelab-users" "false"
create_group "media-users" "false"

# ------------------------------------------------------------------
# Step 2: Create OIDC providers for each service
# ------------------------------------------------------------------
log_step "Creating OIDC providers..."

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
  "https://portainer.${DOMAIN}" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Open-WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
log_step "Setup complete!"

if $DRY_RUN; then
  echo
  echo -e "${BOLD}Groups that would be created:${RESET}"
  echo "  - homelab-admins (superuser)"
  echo "  - homelab-users"
  echo "  - media-users"
  echo
  echo -e "${BOLD}Providers that would be created:${RESET}"
  echo "  - Grafana      → https://grafana.\${DOMAIN}/login/generic_oauth"
  echo "  - Gitea        → https://git.\${DOMAIN}/user/oauth2/Authentik/callback"
  echo "  - Outline      → https://docs.\${DOMAIN}/auth/oidc.callback"
  echo "  - Portainer    → https://portainer.\${DOMAIN}"
  echo "  - Nextcloud    → https://nextcloud.\${DOMAIN}/apps/sociallogin/custom_oidc/authentik"
  echo "  - Open-WebUI   → https://ai.\${DOMAIN}/oauth/oidc/callback"
  echo
  echo -e "${BOLD}Run without --dry-run to apply changes.${RESET}"
else
  echo
  log_info "All providers created. Credentials written to .env"
  log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/<slug>/"
  echo
  echo -e "${BOLD}Next steps:${RESET}"
  echo "  1. Restart services to pick up new OAuth credentials:"
  echo "     cd stacks/monitoring && docker compose up -d"
  echo "     cd stacks/productivity && docker compose up -d"
  echo "     cd stacks/ai && docker compose up -d"
  echo "     cd stacks/base && docker compose up -d"
  echo "  2. Configure Nextcloud OIDC:"
  echo "     ./scripts/nextcloud-oidc-setup.sh"
  echo "  3. Assign users to groups in Authentik admin UI:"
  echo "     https://${AUTHENTIK_DOMAIN}/if/admin/#/identity/groups"
fi
