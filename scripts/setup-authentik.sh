#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Setup Script
# Creates all OIDC/OAuth2 providers and proxy providers for the homelab.
#
# Usage:
#   ./scripts/setup-authentik.sh            # Full setup
#   ./scripts/setup-authentik.sh --dry-run # Preview API calls without changes
#   ./scripts/setup-authentik.sh --wait    # Wait for Authentik to be ready
#
# Requirements: curl, jq
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'; NC='\033[0m'

DRY_RUN=false
WAIT_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --wait) WAIT_ONLY=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }
log_ok()    { echo -e "  ${GREEN}✓${RESET} $*"; }
log_dry()   { echo -e "  ${YELLOW}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="${AUTHENTIK_URL:-https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_info "Generate with: openssl rand -hex 32"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"
CONTENT_TYPE="Content-Type: application/json"

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------

jq_need() {
  command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed"; exit 1; }
}

api_get() {
  local endpoint="$1"
  curl -sf -H "$AUTH_HEADER" -H "$CONTENT_TYPE" \
    "${API_URL}${endpoint}" 2>/dev/null
}

api_post() {
  local endpoint="$1"
  local payload="$2"
  if [ "$DRY_RUN" = true ]; then
    log_dry "POST $API_URL$endpoint"
    log_dry "Payload: $payload"
    echo "{}"
  else
    curl -sf -X POST -H "$AUTH_HEADER" -H "$CONTENT_TYPE" \
      -d "$payload" \
      "${API_URL}${endpoint}" 2>/dev/null
  fi
}

get_pk() {
  local path="$1"
  local key="${2:-pk}"
  api_get "$path" | jq -r ".results[0].${key}" 2>/dev/null || echo ""
}

get_flow_pk() {
  local designation="$1"
  api_get "/flows/instances/?designation=${designation}&ordering=slug" \
    | jq -r '.results[0].pk' 2>/dev/null || echo ""
}

get_signing_key() {
  api_get "/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    | jq -r '.results[0].pk' 2>/dev/null || echo ""
}

write_env() {
  local var="$1"
  local val="$2"
  if [ "$DRY_RUN" = true ]; then
    log_dry "Set $var=$val"
  else
    # Use @ as delimiter since val may contain special chars
    sed -i "s|^${var}=.*|${var}=${val}|" "$ROOT_DIR/.env" 2>/dev/null || true
  fi
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
wait_for_authentik() {
  log_step "Waiting for Authentik API..."
  for i in $(seq 1 60); do
    if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>/dev/null; then
      log_ok "Authentik is ready after ${i}x5s"
      return 0
    fi
    printf "."
    sleep 5
  done
  log_error "Authentik did not become ready in 300s"
  return 1
}

# ------------------------------------------------------------------
# Create OAuth2/OIDC provider + application
# Returns: "pk client_id client_secret"
# ------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local slug="$2"
  local redirect_uris="$3"
  local client_id_var="$4"
  local client_secret_var="$5"

  log_step "Creating OIDC provider: $name"
  echo "  Redirect URI: $redirect_uris"

  local flow_pk signing_key
  flow_pk=$(get_flow_pk authorize)
  signing_key=$(get_signing_key)

  if [ -z "$flow_pk" ] || [ "$flow_pk" = "null" ] || [ -z "$signing_key" ] || [ "$signing_key" = "null" ]; then
    log_warn "Could not get flow_pk ($flow_pk) or signing_key ($signing_key) — skipping $name"
    return 1
  fi

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --arg uris "$redirect_uris" \
    --arg key "$signing_key" \
    '{
      name: $name,
      slug: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $uris,
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      signing_key: $key
    }')

  local response
  response=$(api_post "/providers/oauth2/" "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk' 2>/dev/null || echo "")
  client_id=$(echo "$response" | jq -r '.client_id' 2>/dev/null || echo "")
  client_secret=$(echo "$response" | jq -r '.client_secret' 2>/dev/null || echo "")

  if [ -z "$client_id" ] || [ "$client_id" = "null" ]; then
    log_error "Failed to create provider for $name"
    log_error "Response: $response"
    return 1
  fi

  log_ok "Provider PK: $provider_pk"
  log_ok "Client ID:   $client_id"

  # Create corresponding Application in Authentik
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    '{
      name: $name,
      slug: $slug,
      provider: $pk,
      policy_engine_mode: "any"
    }')

  api_post "/core/applications/" "$app_payload" > /dev/null
  log_ok "Application created: $name → https://${AUTHENTIK_URL#/}/#/core/applications"

  # Write credentials to .env
  write_env "$client_id_var" "$client_id"
  write_env "$client_secret_var" "$client_secret"

  echo "$provider_pk $client_id $client_secret"
}

# ------------------------------------------------------------------
# Create Proxy provider (for Traefik ForwardAuth embedded outpost)
# ------------------------------------------------------------------
create_proxy_provider() {
  log_step "Creating Proxy provider: Traefik ForwardAuth Outpost"

  local flow_pk
  flow_pk=$(get_flow_pk authorization)
  if [ -z "$flow_pk" ] || [ "$flow_pk" = "null" ]; then
    flow_pk=$(get_flow_pk authorize)
  fi

  if [ -z "$flow_pk" ] || [ "$flow_pk" = "null" ]; then
    log_warn "Could not get authorization flow PK — skipping proxy provider"
    return 1
  fi

  local payload
  payload=$(jq -n \
    --arg flow "$flow_pk" \
    '{
      name: "Traefik Outpost",
      slug: "traefik-outpost",
      authorization_flow: $flow,
      enable_proxy_protocol: false,
      mode: "proxy"
    }')

  local response
  response=$(api_post "/providers/proxy/" "$payload")

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk' 2>/dev/null || echo "")
  client_id=$(echo "$response" | jq -r '.client_id' 2>/dev/null || echo "")
  client_secret=$(echo "$response" | jq -r '.client_secret' 2>/dev/null || echo "")

  if [ -z "$client_id" ] || [ "$client_id" = "null" ]; then
    log_error "Failed to create proxy provider"
    log_error "Response: $response"
    return 1
  fi

  log_ok "Proxy Provider PK: $provider_pk"
  log_ok "Client ID:   $client_id"

  # Create application for the proxy provider
  local app_payload
  app_payload=$(jq -n \
    --argjson pk "$provider_pk" \
    '{
      name: "Traefik Outpost",
      slug: "traefik-outpost",
      provider: $pk,
      policy_engine_mode: "any"
    }')

  api_post "/core/applications/" "$app_payload" > /dev/null
  log_ok "Application created: Traefik Outpost"

  write_env "AUTHENTIK_OUTPOST_CLIENT_ID" "$client_id"
  write_env "AUTHENTIK_OUTPOST_CLIENT_SECRET" "$client_secret"

  echo "$provider_pk $client_id $client_secret"
}

# ------------------------------------------------------------------
# Create groups: homelab-admins, homelab-users, media-users
# ------------------------------------------------------------------
create_groups() {
  log_step "Creating Authentik groups"

  local groups=("homelab-admins" "homelab-users" "media-users")
  for group in "${groups[@]}"; do
    local payload
    payload=$(jq -n --arg name "$group" --arg slug "$group" '{
      name: $name,
      slug: $slug
    }')

    # Check if group already exists
    local existing
    existing=$(api_get "/core/groups/?slug=${group}" | jq -r '.results[0].pk' 2>/dev/null || echo "")

    if [ -n "$existing" ] && [ "$existing" != "null" ]; then
      log_ok "Group already exists: $group (PK: $existing)"
    else
      api_post "/core/groups/" "$payload" > /dev/null
      log_ok "Created group: $group"
    fi
  done
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
main() {
  jq_need

  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║       Authentik SSO Setup — HomeLab Stack           ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    log_warn "DRY-RUN mode — no actual changes will be made"
    echo ""
  fi

  wait_for_authentik || exit 1

  if [ "$WAIT_ONLY" = true ]; then
    log_info "Wait complete."
    exit 0
  fi

  echo ""
  echo -e "${BOLD}━━━ Creating Groups ━━━${RESET}"
  create_groups

  echo ""
  echo -e "${BOLD}━━━ Creating OIDC Providers ━━━${RESET}"

  # Grafana — OIDC
  create_oidc_provider \
    "Grafana" \
    "grafana" \
    "https://grafana.${DOMAIN}/login/generic_oauth" \
    "GRAFANA_OAUTH_CLIENT_ID" \
    "GRAFANA_OAUTH_CLIENT_SECRET"

  # Gitea — OIDC
  create_oidc_provider \
    "Gitea" \
    "gitea" \
    "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
    "GITEA_OAUTH_CLIENT_ID" \
    "GITEA_OAUTH_CLIENT_SECRET"

  # Outline — OIDC
  create_oidc_provider \
    "Outline" \
    "outline" \
    "https://docs.${DOMAIN}/auth/oidc.callback" \
    "OUTLINE_OAUTH_CLIENT_ID" \
    "OUTLINE_OAUTH_CLIENT_SECRET"

  # Bookstack — OIDC
  create_oidc_provider \
    "Bookstack" \
    "bookstack" \
    "https://wiki.${DOMAIN}/login/oidc/Authentik/callback" \
    "BOOKSTACK_OIDC_CLIENT_ID" \
    "BOOKSTACK_OIDC_CLIENT_SECRET"

  # Nextcloud — OIDC (via Social Login app)
  create_oidc_provider \
    "Nextcloud" \
    "nextcloud" \
    "https://nextcloud.${DOMAIN}/apps/social_login_oauth/Authentik" \
    "NEXTCLOUD_OIDC_CLIENT_ID" \
    "NEXTCLOUD_OIDC_CLIENT_SECRET"

  # Open WebUI — OIDC
  create_oidc_provider \
    "Open WebUI" \
    "open-webui" \
    "https://ai.${DOMAIN}/auth oidc/callback" \
    "OPEN_WEBUI_OIDC_CLIENT_ID" \
    "OPEN_WEBUI_OIDC_CLIENT_SECRET"

  # Jellyseerr — OIDC
  create_oidc_provider \
    "Jellyseerr" \
    "jellyseerr" \
    "https://requests.${DOMAIN}/api/auth oidc/callback" \
    "JELLYSEERR_OIDC_CLIENT_ID" \
    "JELLYSEERR_OIDC_CLIENT_SECRET"

  # Portainer — OAuth2
  create_oidc_provider \
    "Portainer" \
    "portainer" \
    "https://portainer.${DOMAIN}/" \
    "PORTAINER_OAUTH_CLIENT_ID" \
    "PORTAINER_OAUTH_CLIENT_SECRET"

  echo ""
  echo -e "${BOLD}━━━ Creating Proxy Provider (Traefik ForwardAuth) ━━━${RESET}"
  create_proxy_provider || log_warn "Proxy provider creation failed — ForwardAuth may not work"

  echo ""
  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║         ✓ All providers created successfully!        ║${RESET}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${CYAN}Next steps:${RESET}"
  echo ""
  echo "  1. Open Authentik admin UI: https://${AUTHENTIK_DOMAIN}"
  echo "     Login with: ${AUTHENTIK_BOOTSTRAP_EMAIL}"
  echo ""
  echo "  2. In Authentik Admin UI:"
  echo "     - Add users to groups: homelab-admins, homelab-users, media-users"
  echo "     - Assign applications to groups (Property mappings)"
  echo ""
  echo "  3. For Portainer OAuth:"
  echo "     - In Portainer UI → Settings → Authentication → OAuth"
  echo "     - Configure Custom OAuth with credentials from .env"
  echo ""
  echo "  4. For Nextcloud:"
  echo "     - Install 'Social Login' app"
  echo "     - In Nextcloud Admin → Social Login → Add Authentik provider"
  echo "     - Use client ID/secret from .env"
  echo ""
  echo "  5. For Jellyfin:"
  echo "     - In Jellyfin Admin → Dashboard → Authentication → New Authentication"
  echo "     - Enable OIDC provider with client ID/secret from .env"
  echo ""
  echo "  6. Restart affected services:"
  echo "     cd stacks/productivity && docker compose restart outline bookstack"
  echo "     cd stacks/ai && docker compose restart open-webui"
  echo "     cd stacks/media && docker compose restart jellyseerr"
  echo ""
}

main "$@"
