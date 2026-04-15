#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik SSO Auto-Provisioning Script
# Creates OIDC providers + applications for: Grafana, Gitea, Outline,
# Portainer, Nextcloud, and a ForwardAuth provider for Traefik proxy.
#
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh              # provision all clients
#   ./scripts/setup-authentik.sh --dry-run    # show what would be created
#   ./scripts/setup-authentik.sh --status     # check existing providers
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# --- Load .env ---------------------------------------------------------------
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo "[ERROR] $ROOT_DIR/.env not found. Copy from .env.example first." >&2
  exit 1
fi

# --- Colors & logging --------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_ok()    { echo -e "${GREEN}  ✓${RESET} $*"; }

# --- Configuration -----------------------------------------------------------
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="${AUTHENTIK_URL}/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
DRY_RUN=false
STATUS_ONLY=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --status)   STATUS_ONLY=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--status]"
      echo "  --dry-run   Show what would be created without making changes"
      echo "  --status    Check existing providers and applications"
      exit 0
      ;;
  esac
done

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_error "Generate one with: openssl rand -hex 32"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# --- Check dependencies ------------------------------------------------------
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    log_error "'$cmd' is required but not installed."
    exit 1
  fi
done

# --- API helper functions ----------------------------------------------------
api_get() {
  curl -sf "$API_URL/$1" -H "$AUTH_HEADER" -H "Content-Type: application/json"
}

api_post() {
  curl -sf -X POST "$API_URL/$1" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$2"
}

get_default_flow() {
  local designation="$1"
  api_get "flows/instances/?designation=${designation}&ordering=slug" | \
    jq -r '.results[0].pk // empty'
}

get_signing_key() {
  api_get "crypto/certificatekeypairs/?has_key=true&ordering=name" | \
    jq -r '.results[0].pk // empty'
}

check_provider_exists() {
  local name="$1"
  local count
  count=$(api_get "providers/oauth2/?search=${name}" | jq '.results | length')
  [ "$count" -gt 0 ]
}

check_application_exists() {
  local slug="$1"
  api_get "core/applications/${slug}/" &>/dev/null
}

# --- Status mode -------------------------------------------------------------
if [ "$STATUS_ONLY" = true ]; then
  log_step "Checking Authentik status"

  if ! curl -sf "${AUTHENTIK_URL}/-/health/ready/" -o /dev/null 2>/dev/null; then
    log_error "Authentik is not reachable at ${AUTHENTIK_URL}"
    exit 1
  fi
  log_ok "Authentik API is healthy"

  log_step "Existing OIDC providers"
  api_get "providers/oauth2/" | jq -r '.results[] | "  \(.name) (client_id: \(.client_id))"'

  log_step "Existing applications"
  api_get "core/applications/" | jq -r '.results[] | "  \(.name) → \(.launch_url // "no launch URL")"'

  log_step "Existing outposts"
  api_get "outposts/instances/" | jq -r '.results[] | "  \(.name) (type: \(.type))"'

  exit 0
fi

# --- Wait for Authentik to be ready ------------------------------------------
log_step "Waiting for Authentik API at ${AUTHENTIK_URL}..."
RETRIES=0
MAX_RETRIES=30
while ! curl -sf "${AUTHENTIK_URL}/-/health/ready/" -o /dev/null 2>/dev/null; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
    log_error "Authentik did not become ready after $((MAX_RETRIES * 5))s"
    log_error "Check: docker compose -f stacks/sso/docker-compose.yml logs authentik-server"
    exit 1
  fi
  printf "."
  sleep 5
done
echo
log_ok "Authentik is ready"

# --- Fetch defaults ----------------------------------------------------------
log_step "Fetching default flows and signing keys..."
AUTH_FLOW=$(get_default_flow "authorization")
INVAL_FLOW=$(get_default_flow "invalidation")
SIGNING_KEY=$(get_signing_key)

if [ -z "$AUTH_FLOW" ]; then
  log_error "No authorization flow found. Complete Authentik initial setup first."
  exit 1
fi
log_ok "Authorization flow: ${AUTH_FLOW}"
log_ok "Signing key: ${SIGNING_KEY:-none (will create unsigned tokens)}"

# --- OIDC provider creation --------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uris="$2"
  local client_id_var="$3"
  local client_secret_var="$4"
  local launch_url="${5:-}"
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  log_step "OIDC Provider: ${name}"

  # Skip if already exists
  if check_provider_exists "$name"; then
    log_warn "Provider '${name}' already exists — skipping"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create provider: ${name}"
    log_info "  Redirect URIs: ${redirect_uris}"
    log_info "  .env vars: ${client_id_var}, ${client_secret_var}"
    return 0
  fi

  # Build provider payload
  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$AUTH_FLOW" \
    --arg uris "$redirect_uris" \
    --arg key "$SIGNING_KEY" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $uris,
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      property_mappings: [],
      access_code_validity: "minutes=1",
      access_token_validity: "minutes=5",
      refresh_token_validity: "days=30"
    } + (if $key != "" then {signing_key: $key} else {} end)')

  local response
  response=$(api_post "providers/oauth2/" "$payload")
  if [ -z "$response" ]; then
    log_error "Failed to create provider '${name}'"
    return 1
  fi

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  log_ok "Provider PK: ${provider_pk}"
  log_ok "Client ID:   ${client_id}"

  # Write credentials to .env
  if grep -q "^${client_id_var}=" "$ROOT_DIR/.env" 2>/dev/null; then
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
  else
    echo "${client_id_var}=${client_id}" >> "$ROOT_DIR/.env"
    echo "${client_secret_var}=${client_secret}" >> "$ROOT_DIR/.env"
  fi

  # Create application
  if ! check_application_exists "$slug"; then
    local app_payload
    app_payload=$(jq -n \
      --arg name "$name" \
      --arg slug "$slug" \
      --argjson pk "$provider_pk" \
      --arg url "$launch_url" \
      '{
        name: $name,
        slug: $slug,
        provider: $pk,
        meta_launch_url: (if $url != "" then $url else null end),
        policy_engine_mode: "any"
      }')
    api_post "core/applications/" "$app_payload" > /dev/null
    log_ok "Application created: ${name} (slug: ${slug})"
  fi
}

# --- ForwardAuth provider for Traefik ----------------------------------------
create_forward_auth_provider() {
  local name="$1"
  local external_host="$2"

  log_step "ForwardAuth Provider: ${name}"

  if check_provider_exists "$name"; then
    log_warn "Provider '${name}' already exists — skipping"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create ForwardAuth provider: ${name}"
    log_info "  External host: ${external_host}"
    return 0
  fi

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$AUTH_FLOW" \
    --arg host "$external_host" \
    '{
      name: $name,
      authorization_flow: $flow,
      external_host: $host,
      mode: "forward_single",
      access_token_validity: "minutes=5"
    }')

  local response
  response=$(api_post "providers/proxy/" "$payload")
  if [ -z "$response" ]; then
    log_error "Failed to create ForwardAuth provider '${name}'"
    return 1
  fi

  local provider_pk
  provider_pk=$(echo "$response" | jq -r '.pk')
  log_ok "ForwardAuth provider PK: ${provider_pk}"

  # Create application
  if ! check_application_exists "$slug"; then
    local app_payload
    app_payload=$(jq -n \
      --arg name "$name" \
      --arg slug "$slug" \
      --argjson pk "$provider_pk" \
      --arg url "$external_host" \
      '{name: $name, slug: $slug, provider: $pk, meta_launch_url: $url, policy_engine_mode: "any"}')
    api_post "core/applications/" "$app_payload" > /dev/null
    log_ok "Application created: ${name}"
  fi
}

# =============================================================================
# Provision OIDC Clients
# =============================================================================

# Grafana — native OIDC
create_oidc_provider \
  "Grafana" \
  "https://grafana.${DOMAIN}/login/generic_oauth" \
  "GRAFANA_OAUTH_CLIENT_ID" \
  "GRAFANA_OAUTH_CLIENT_SECRET" \
  "https://grafana.${DOMAIN}"

# Gitea — native OIDC
create_oidc_provider \
  "Gitea" \
  "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
  "GITEA_OAUTH_CLIENT_ID" \
  "GITEA_OAUTH_CLIENT_SECRET" \
  "https://git.${DOMAIN}"

# Outline — native OIDC
create_oidc_provider \
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET" \
  "https://outline.${DOMAIN}"

# Portainer — native OIDC
create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET" \
  "https://portainer.${DOMAIN}"

# Nextcloud — native OIDC (via user_oidc app)
create_oidc_provider \
  "Nextcloud" \
  "https://cloud.${DOMAIN}/apps/user_oidc/code\nhttps://cloud.${DOMAIN}/apps/oidc_login/oidc" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET" \
  "https://cloud.${DOMAIN}"

# =============================================================================
# Provision ForwardAuth Providers (for services without native OIDC)
# =============================================================================

# Example: protect Prometheus behind Authentik ForwardAuth
create_forward_auth_provider \
  "Prometheus" \
  "https://prometheus.${DOMAIN}"

# =============================================================================
# Summary
# =============================================================================
log_step "Setup complete!"
echo
log_info "Authentik Admin UI:  ${AUTHENTIK_URL}/if/admin/"
log_info "Authentik User Portal: ${AUTHENTIK_URL}/if/user/"
echo
log_info "OIDC Issuer URLs (for service config):"
log_info "  Grafana:    ${AUTHENTIK_URL}/application/o/grafana/"
log_info "  Gitea:      ${AUTHENTIK_URL}/application/o/gitea/"
log_info "  Outline:    ${AUTHENTIK_URL}/application/o/outline/"
log_info "  Portainer:  ${AUTHENTIK_URL}/application/o/portainer/"
log_info "  Nextcloud:  ${AUTHENTIK_URL}/application/o/nextcloud/"
echo
log_info "OAuth2 credentials have been written to ${ROOT_DIR}/.env"
echo
log_info "Next steps:"
log_info "  1. Restart services that need OAuth credentials:"
log_info "     cd stacks/monitoring && docker compose up -d"
log_info "  2. Configure each service to use the OIDC provider (see README.md)"
log_info "  3. (Optional) Enable LDAP outpost in docker-compose.yml"
log_info "  4. (Optional) Set up MFA in Authentik Admin → Flows → default-authentication-flow"
