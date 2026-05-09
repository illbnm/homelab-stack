#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Setup Script (Enhanced)
# Creates OIDC providers for ALL services (Grafana,Gitea,Nextcloud,Outline,
# OpenWebUI,Portainer) and outputs credentials.
#
# Features:
#   --dry-run        Preview without making changes
#   --service NAME   Create provider for single service
#   --reset NAME     Delete and recreate provider for single service
#
# Requires: curl, jq, docker (Authentik must be running)
# Usage: ./scripts/authentik-setup.sh [--dry-run] [--service grafana]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# ── Config ───────────────────────────────────────────────────────────────────
DRY_RUN=false
TARGET_SERVICE=""
RESET_SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --service) TARGET_SERVICE="$2"; shift 2 ;;
    --reset) RESET_SERVICE="$2"; shift 2 ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
OIDC_ENV_FILE="$ROOT_DIR/config/oidc.env"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ── Helper functions ─────────────────────────────────────────────────────────
get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

delete_existing_provider() {
  local name="$1"
  local existing_pk
  existing_pk=$(curl -sf "$API_URL/providers/oauth2/?search=$(echo "$name" | jq -sRr @uri)" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty')
  if [ -n "$existing_pk" ] && [ "$existing_pk" != "null" ]; then
    log_warn "Deleting existing provider: $name (PK: $existing_pk)"
    if ! $DRY_RUN; then
      curl -sf -X DELETE "$API_URL/providers/oauth2/$existing_pk/" -H "$AUTH_HEADER" || true
    fi
  fi
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local extra_uris="${5:-}"

  log_step "Creating OIDC provider: $name"

  # Handle reset
  if [ "$RESET_SERVICE" = "$name" ] || [ "$RESET_SERVICE" = "all" ]; then
    delete_existing_provider "$name"
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)

  if [ -z "$flow_pk" ] || [ "$flow_pk" = "null" ]; then
    log_error "Could not find authorization flow. Is Authentik running?"
    return 1
  fi
  if [ -z "$signing_key" ] || [ "$signing_key" = "null" ]; then
    log_error "Could not find signing key. Run Authentik setup first."
    return 1
  fi

  # Build redirect URIs
  local uris="$redirect_uri"
  if [ -n "$extra_uris" ]; then
    uris="$redirect_uri\n$extra_uris"
  fi

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would create OIDC provider: $name"
    log_info "  Redirect URI: $redirect_uri"
    log_info "  Slug: $slug"
    return 0
  fi

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

  log_info "  Provider PK:  $provider_pk"
  log_info "  Client ID:    $client_id"
  log_info "  Client Secret: $client_secret"

  # Update oidc.env
  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$OIDC_ENV_FILE"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$OIDC_ENV_FILE"

  # Create Application in Authentik
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

  log_info "  Application created: $slug"

  echo "$client_id|$client_secret|$provider_pk"
}

# ── Service definitions ──────────────────────────────────────────────────────
declare -A SERVICES
SERVICES=(
  ["grafana"]="https://${GRAFANA_DOMAIN}/login/generic_oauth|GF_AUTH_GENERIC_OAUTH_CLIENT_ID|GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET|"
  ["gitea"]="https://${GIT_DOMAIN}/user/oauth2/authentik/callback|GITEA_OAUTH2_CLIENT_ID|GITEA_OAUTH2_CLIENT_SECRET|"
  ["nextcloud"]="https://${NEXTCLOUD_DOMAIN}/apps/sociallogin/custom_oidc/authentik|NEXTCLOUD_OIDC_CLIENT_ID|NEXTCLOUD_OIDC_CLIENT_SECRET|"
  ["outline"]="https://${OUTLINE_DOMAIN}/auth/oidc.callback|OIDC_CLIENT_ID|OIDC_CLIENT_SECRET|"
  ["openwebui"]="https://${OPEN_WEBUI_DOMAIN}/oauth/oidc/callback|OPEN_WEBUI_OIDC_CLIENT_ID|OPEN_WEBUI_OIDC_CLIENT_SECRET|"
  ["portainer"]="https://${PORTAINER_DOMAIN}/#/auth/oauth|PORTAINER_OAUTH_CLIENT_ID|PORTAINER_OAUTH_CLIENT_SECRET|"
)

# ── Group creation ───────────────────────────────────────────────────────────
create_groups() {
  if $DRY_RUN; then
    log_info "[DRY-RUN] Would create groups: homelab-admins, homelab-users, media-users"
    return
  fi

  log_step "Creating user groups"
  for group in "homelab-admins" "homelab-users" "media-users"; do
    local exists
    exists=$(curl -sf "$API_URL/core/groups/?name=$group" -H "$AUTH_HEADER" | jq -r '.results | length')
    if [ "$exists" -gt 0 ]; then
      log_info "  Group exists: $group"
    else
      curl -sf -X POST "$API_URL/core/groups/" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$group\"}" > /dev/null
      log_info "  Created group: $group"
    fi
  done
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   Authentik SSO Setup — HomeLab Stack       ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${RESET}"
echo ""

# Check Authentik is reachable
if ! curl -sf "$AUTHENTIK_URL/-/health/ready/" > /dev/null 2>&1; then
  log_error "Cannot reach Authentik at $AUTHENTIK_URL"
  log_error "Is the SSO stack running? cd stacks/sso && docker compose up -d"
  exit 1
fi
log_info "Authentik is reachable at $AUTHENTIK_URL"

# Initialize oidc.env if needed
if [ ! -f "$OIDC_ENV_FILE" ]; then
  log_warn "$OIDC_ENV_FILE not found, creating from template..."
  cp "$ROOT_DIR/config/oidc.env.example" "$OIDC_ENV_FILE" 2>/dev/null || touch "$OIDC_ENV_FILE"
fi

# Create groups
create_groups

# Create providers
echo ""
echo -e "${BOLD}Service Credentials:${RESET}"
echo -e "${BOLD}────────────────────${RESET}"

for service in "${!SERVICES[@]}"; do
  if [ -n "$TARGET_SERVICE" ] && [ "$TARGET_SERVICE" != "$service" ]; then
    continue
  fi

  IFS='|' read -r redirect_uri client_id_var client_secret_var extra_uris <<< "${SERVICES[$service]}"
  
  # Capitalize service name for display
  local display_name
  display_name=$(echo "$service" | sed 's/\b./\u&/g')
  [ "$service" = "openwebui" ] && display_name="OpenWebUI"

  result=$(create_oidc_provider "$display_name" "$redirect_uri" "$client_id_var" "$client_secret_var" "$extra_uris")
  
  if [ -n "$result" ] && [ "$result" != "null" ]; then
    IFS='|' read -r cid csecret cpk <<< "$result"
    echo -e "  ${GREEN}✓${RESET} ${BOLD}${display_name}${RESET}"
    echo "    Client ID:     $cid"
    echo "    Client Secret: $csecret"
    echo "    Redirect URI:  $redirect_uri"
    echo ""
  fi
done

echo -e "${BOLD}${GREEN}Done!${RESET} Credentials saved to ${OIDC_ENV_FILE}"
echo ""
echo "Next steps:"
echo "  1. Source the env:     source config/oidc.env"
echo "  2. Restart services:   docker compose -f stacks/monitoring/docker-compose.yml up -d"
echo "  3. Configure Nextcloud: ./scripts/nextcloud-oidc-setup.sh"
echo "  4. Verify login:        Open each service and click 'Login with Authentik'"
