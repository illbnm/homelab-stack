#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for Grafana, Gitea, Outline, Portainer, Nextcloud,
# OpenWebUI via Authentik API. Auto-creates matching Applications.
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh            # Create all providers
#   ./scripts/setup-authentik.sh --dry-run   # Show what would be created
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${DIM}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ---------------------------------------------------------------------------
# API helpers
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
# Provider definitions: name|redirect_uri|client_id_var|client_secret_var|post_logout_uri(optional)
# ---------------------------------------------------------------------------
PROVIDERS=(
  "Grafana|https://grafana.${DOMAIN}/login/generic_oauth|GRAFANA_OAUTH_CLIENT_ID|GRAFANA_OAUTH_CLIENT_SECRET|https://grafana.${DOMAIN}/"
  "Gitea|https://git.${DOMAIN}/user/oauth2/Authentik/callback|GITEA_OAUTH_CLIENT_ID|GITEA_OAUTH_CLIENT_SECRET|"
  "Outline|https://outline.${DOMAIN}/auth/oidc.callback|OUTLINE_OAUTH_CLIENT_ID|OUTLINE_OAUTH_CLIENT_SECRET|"
  "Portainer|https://portainer.${DOMAIN}/|PORTAINER_OAUTH_CLIENT_ID|PORTAINER_OAUTH_CLIENT_SECRET|"
  "Nextcloud|https://nextcloud.${DOMAIN}/apps/user_oidc/callback|NEXTCLOUD_OAUTH_CLIENT_ID|NEXTCLOUD_OAUTH_CLIENT_SECRET|"
  "OpenWebUI|https://chat.${DOMAIN}/oauth/oidc/callback|OPENWEBUI_OAUTH_CLIENT_ID|OPENWEBUI_OAUTH_CLIENT_SECRET|"
)

# ---------------------------------------------------------------------------
# Create OIDC Provider + Application
# ---------------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local post_logout_uri="$5"

  log_step "Creating OIDC provider: $name"

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if $DRY_RUN; then
    log_dry "  Would create provider: ${name} Provider"
    log_dry "  Redirect URI:  $redirect_uri"
    log_dry "  Post-logout:   ${post_logout_uri:-<none>}"
    log_dry "  Client ID var: $client_id_var"
    log_dry "  Client Secret var: $client_secret_var"
    log_dry "  Application:   $name (slug: $slug)"
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)

  # Build redirect_uris array
  local uris_array
  if [ -n "$post_logout_uri" ]; then
    uris_array=$(jq -n --arg uri "$redirect_uri" --arg logout "$post_logout_uri" \
      '[$uri, $logout]')
  else
    uris_array=$(jq -n --arg uri "$redirect_uri" '[$uri]')
  fi

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --argjson uris "$uris_array" \
    --arg key "$signing_key" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $uris,
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
  log_info "  Client Secret: ${client_secret:0:8}... (full value in .env)"

  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"

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

  log_info "  Application created: $name (slug: $slug)"
}

# ---------------------------------------------------------------------------
# Create groups
# ---------------------------------------------------------------------------
create_groups() {
  local groups=("admins" "users" "media-users")

  for group in "${groups[@]}"; do
    if $DRY_RUN; then
      log_dry "Would create group: $group"
      continue
    fi

    # Check if group already exists
    local existing
    existing=$(curl -sf "$API_URL/core/groups/?name=${group}" -H "$AUTH_HEADER" \
      | jq -r '.results | length')

    if [ "$existing" -gt 0 ]; then
      log_info "Group '$group' already exists, skipping"
      continue
    fi

    curl -sf -X POST "$API_URL/core/groups/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg name "$group" '{name: $name}')" > /dev/null

    log_info "Group created: $group"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if $DRY_RUN; then
  log_step "DRY RUN — no changes will be made"
  log_info "Authentik URL: $AUTHENTIK_URL"
  log_info "Providers to create: ${#PROVIDERS[@]}"
else
  # Wait for Authentik to be ready
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

# Create user groups
log_step "Creating default groups"
create_groups

# Create providers
for entry in "${PROVIDERS[@]}"; do
  IFS='|' read -r name redirect_uri cid_var cs_var logout_uri <<< "$entry"
  create_oidc_provider "$name" "$redirect_uri" "$cid_var" "$cs_var" "$logout_uri"
done

echo
log_step "Done!"
log_info "OIDC issuer base: $AUTHENTIK_URL/application/o/<slug>/"
log_info "Credentials written to $ROOT_DIR/.env"
