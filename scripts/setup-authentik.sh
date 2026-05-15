#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Setup Script
# Creates OIDC providers for Grafana, Gitea, Outline, Nextcloud, Open WebUI,
# Portainer, and BookStack. Also creates user groups for RBAC.
#
# Requires: curl, jq
#
# Usage:
#   ./scripts/setup-authentik.sh              # Create all providers
#   ./scripts/setup-authentik.sh --dry-run    # Preview without making changes
#   ./scripts/setup-authentik.sh --groups-only # Only create user groups
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env from root
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi
# Also load from stacks/sso/.env if it exists
if [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
fi

# -------------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------------
DRY_RUN=false
GROUPS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --groups-only) GROUPS_ONLY=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--groups-only]"
      echo "  --dry-run     Preview changes without making API calls"
      echo "  --groups-only Only create user groups (skip provider creation)"
      exit 0
      ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_ok()    { echo -e "  ${GREEN}[OK]${RESET} $*"; }
log_dry()   { echo -e "  ${YELLOW}[DRY-RUN]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# -------------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------------
get_default_flow() {
  local designation="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "dry-run-flow-pk"
    return
  fi
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  if [ "$DRY_RUN" = true ]; then
    echo "dry-run-key-pk"
    return
  fi
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

create_group() {
  local name="$1"
  local is_superuser="${2:-false}"

  if [ "$DRY_RUN" = true ]; then
    log_dry "Create group: $name (superuser=$is_superuser)"
    return
  fi

  # Check if group already exists
  local existing
  existing=$(curl -sf "$API_URL/core/groups/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$name'))")" \
    -H "$AUTH_HEADER" | jq -r '.results | length')

  if [ "$existing" -gt 0 ] 2>/dev/null; then
    log_info "  Group '$name' already exists — skipping"
    return
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --argjson super "$is_superuser" \
    '{name: $name, is_superuser: $super}')

  curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null

  log_ok "Created group: $name"
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  log_step "Creating OIDC provider: $name"

  if [ "$DRY_RUN" = true ]; then
    log_dry "Provider: ${name} Provider"
    log_dry "  Redirect URI: $redirect_uri"
    log_dry "  Client ID var: $client_id_var"
    log_dry "  Client Secret var: $client_secret_var"
    log_dry "  Application slug: $slug"
    log_dry "  Auth URL: ${AUTHENTIK_URL}/application/o/${slug}/authorize/"
    log_dry "  Token URL: ${AUTHENTIK_URL}/application/o/${slug}/token/"
    log_dry "  UserInfo URL: ${AUTHENTIK_URL}/application/o/${slug}/userinfo/"
    return
  fi

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
      signing_key: $key,
      property_mappings: []
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

  log_ok "Created provider: $name"
  log_info "     Client ID:     $client_id"
  log_info "     Client Secret: $client_secret"
  log_info "     Redirect URI:  $redirect_uri"

  # Write credentials to .env
  sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"

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

  log_info "     Application created: $name (slug: $slug)"
}

# -------------------------------------------------------------------------
# Wait for Authentik to be ready
# -------------------------------------------------------------------------
if [ "$DRY_RUN" = false ]; then
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
else
  log_step "[DRY-RUN] Skipping Authentik readiness check"
fi

# -------------------------------------------------------------------------
# Create user groups (RBAC)
# -------------------------------------------------------------------------
log_step "Creating user groups..."
create_group "homelab-admins" "true"
create_group "homelab-users" "false"
create_group "media-users" "false"

if [ "$GROUPS_ONLY" = true ]; then
  log_step "Groups-only mode — skipping provider creation"
  log_info "Done."
  exit 0
fi

# -------------------------------------------------------------------------
# Create OIDC providers
# -------------------------------------------------------------------------
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
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/index.php/apps/sociallogin/custom_oidc/authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Open WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "BookStack" \
  "https://wiki.${DOMAIN}/oidc/callback" \
  "BOOKSTACK_OIDC_CLIENT_ID" \
  "BOOKSTACK_OIDC_CLIENT_SECRET"

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
log_step "Setup complete!"
log_info ""
log_info "Groups created:"
log_info "  homelab-admins  → Superuser access to all services"
log_info "  homelab-users   → Standard user access"
log_info "  media-users     → Media stack only (Jellyfin, Jellyseerr)"
log_info ""
log_info "Providers created. Credentials written to .env"
log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/<slug>/"
log_info ""
log_info "Next steps:"
log_info "  1. For services with native OIDC (Grafana, Gitea, Outline, BookStack):"
log_info "     OAuth credentials are now in .env — restart those stacks to apply."
log_info "  2. For services with ForwardAuth only:"
log_info "     Authentik proxy outpost handles auth via Traefik middleware."
log_info "     Ensure the SSO stack is running before other stacks."
log_info "  3. For Nextcloud OIDC: run the dedicated setup script:"
log_info "     ./scripts/nextcloud-oidc-setup.sh"
log_info "  4. Assign users to groups in Authentik admin UI:"
log_info "     $AUTHENTIK_URL/if/admin/#/identity/groups"
log_info "  5. Verify everything with:"
log_info "     ./scripts/test-sso.sh"
