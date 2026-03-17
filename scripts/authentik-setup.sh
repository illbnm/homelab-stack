#!/usr/bin/env bash
# =============================================================================
# authentik-setup.sh — Automated Authentik OIDC/OAuth2 Provider Setup
# =============================================================================
# Creates all OAuth2/OIDC providers, applications, and the ForwardAuth outpost.
# Outputs Client ID + Client Secret for each service so you can paste into .env
#
# Usage:
#   ./scripts/authentik-setup.sh              # Full setup
#   ./scripts/authentik-setup.sh --dry-run    # Preview only (no changes)
#   ./scripts/authentik-setup.sh --service grafana  # Setup single service
#
# Requirements:
#   - Authentik running and accessible at https://auth.${DOMAIN}
#   - AUTHENTIK_ADMIN_EMAIL and AUTHENTIK_ADMIN_PASSWORD set in .env
#   - curl and jq installed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
else
  echo "ERROR: .env not found at ${ROOT_DIR}/.env" >&2
  exit 1
fi

# =============================================================================
# Config
# =============================================================================
DRY_RUN=false
TARGET_SERVICE=""
AUTHENTIK_URL="https://auth.${DOMAIN}"
API="${AUTHENTIK_URL}/api/v3"
TOKEN=""
FLOW_UUID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Arg parsing
# =============================================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --service) TARGET_SERVICE="${2:-}"; shift ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--service <name>]"
      echo "Services: grafana gitea nextcloud outline openwebui portainer"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

if [[ "${DRY_RUN}" == "true" ]]; then
  echo -e "${YELLOW}[DRY RUN] No changes will be made.${NC}"
fi

# =============================================================================
# Functions
# =============================================================================

log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_info() { echo -e "${BLUE}[--]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!!]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC} $*" >&2; }

check_deps() {
  for cmd in curl jq; do
    if ! command -v "${cmd}" &>/dev/null; then
      log_err "Missing dependency: ${cmd}"
      exit 1
    fi
  done
}

wait_for_authentik() {
  log_info "Waiting for Authentik at ${AUTHENTIK_URL} ..."
  local retries=30
  while [[ ${retries} -gt 0 ]]; do
    if curl -sf "${AUTHENTIK_URL}/-/health/ready/" &>/dev/null; then
      log_ok "Authentik is ready"
      return 0
    fi
    retries=$(( retries - 1 ))
    sleep 5
  done
  log_err "Authentik did not become ready in time"
  exit 1
}

authenticate() {
  log_info "Authenticating as ${AUTHENTIK_ADMIN_EMAIL} ..."
  local response
  response=$(curl -sf -X POST "${API}/core/tokens/" \
    -H "Content-Type: application/json" \
    -u "${AUTHENTIK_ADMIN_EMAIL}:${AUTHENTIK_ADMIN_PASSWORD}" \
    -d '{"identifier": "setup-script-token", "intent": "api", "description": "Created by authentik-setup.sh", "expiring": false}' 2>/dev/null || true)

  if [[ -z "${response}" ]]; then
    # Try direct API token approach using session cookie
    response=$(curl -sf -X POST "${AUTHENTIK_URL}/api/v3/core/tokens/" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${AUTHENTIK_SECRET_KEY}" \
      -d '{"identifier": "setup-script-token", "intent": "api"}' 2>/dev/null || true)
  fi

  # Fallback: use admin API key from env if set
  if [[ -n "${AUTHENTIK_API_TOKEN:-}" ]]; then
    TOKEN="${AUTHENTIK_API_TOKEN}"
    log_ok "Using API token from env"
    return 0
  fi

  # Prompt for API token if needed
  log_warn "Could not auto-generate API token."
  log_info "Create an API token in Authentik Admin UI:"
  log_info "  ${AUTHENTIK_URL}/if/admin/#/admin/token"
  echo -n "Paste API Token: "
  read -r TOKEN
  if [[ -z "${TOKEN}" ]]; then
    log_err "No API token provided"
    exit 1
  fi
  log_ok "API token set"
}

api_get() {
  local path="$1"
  curl -sf -H "Authorization: Bearer ${TOKEN}" "${API}${path}"
}

api_post() {
  local path="$1"
  local data="$2"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] POST ${path}${NC}"
    echo "${data}" | jq '.' 2>/dev/null || echo "${data}"
    return 0
  fi
  curl -sf -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${API}${path}" \
    -d "${data}"
}

get_or_create_flow() {
  # Get the default authorization flow UUID
  local flows
  flows=$(api_get "/flows/instances/?designation=authorization" 2>/dev/null || echo '{"results":[]}')
  FLOW_UUID=$(echo "${flows}" | jq -r '.results[0].pk // empty')
  if [[ -z "${FLOW_UUID}" ]]; then
    log_warn "Could not determine authorization flow UUID — using default"
    FLOW_UUID="default"
  fi
  log_info "Authorization flow: ${FLOW_UUID}"
}

create_provider() {
  local name="$1"
  local slug="$2"
  local redirect_uri="$3"

  log_info "Creating OAuth2 provider: ${name}"

  local payload
  payload=$(jq -n \
    --arg name "${name}" \
    --arg slug "${slug}" \
    --arg redirect_uri "${redirect_uri}" \
    --arg flow "${FLOW_UUID}" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: $redirect_uri,
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      signing_key: null,
      property_mappings: []
    }')

  local result
  result=$(api_post "/providers/oauth2/" "${payload}" 2>/dev/null || echo '{}')

  local client_id client_secret pk
  client_id=$(echo "${result}" | jq -r '.client_id // empty')
  client_secret=$(echo "${result}" | jq -r '.client_secret // empty')
  pk=$(echo "${result}" | jq -r '.pk // empty')

  if [[ -z "${client_id}" ]]; then
    log_warn "Provider ${name} may already exist or creation failed"
    # Try to find existing
    local existing
    existing=$(api_get "/providers/oauth2/?name=${name}" 2>/dev/null || echo '{"results":[]}')
    client_id=$(echo "${existing}" | jq -r '.results[0].client_id // "N/A"')
    client_secret=$(echo "${existing}" | jq -r '.results[0].client_secret // "N/A"')
    pk=$(echo "${existing}" | jq -r '.results[0].pk // empty')
  fi

  echo "${pk}:${client_id}:${client_secret}"
}

create_application() {
  local name="$1"
  local slug="$2"
  local provider_pk="$3"
  local description="$4"

  log_info "Creating application: ${name}"

  local payload
  payload=$(jq -n \
    --arg name "${name}" \
    --arg slug "${slug}" \
    --argjson provider_pk "${provider_pk}" \
    --arg description "${description}" \
    '{
      name: $name,
      slug: $slug,
      provider: $provider_pk,
      meta_description: $description,
      meta_launch_url: "",
      open_in_new_tab: false
    }')

  api_post "/core/applications/" "${payload}" >/dev/null 2>&1 || \
    log_warn "Application ${name} may already exist"
}

setup_service() {
  local service_name="$1"
  local app_name="$2"
  local slug="$3"
  local redirect_uri="$4"
  local env_prefix="$5"
  local description="$6"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Setting up: ${app_name}"

  local result provider_pk client_id client_secret
  result=$(create_provider "${app_name}" "${slug}" "${redirect_uri}")
  provider_pk=$(echo "${result}" | cut -d: -f1)
  client_id=$(echo "${result}" | cut -d: -f2)
  client_secret=$(echo "${result}" | cut -d: -f3)

  if [[ -n "${provider_pk}" && "${provider_pk}" != "null" ]]; then
    create_application "${app_name}" "${slug}" "${provider_pk}" "${description}"
  fi

  log_ok "Created provider: ${app_name}"
  echo "     Client ID:     ${client_id}"
  echo "     Client Secret: ${client_secret}"
  echo "     Redirect URI:  ${redirect_uri}"
  echo ""
  echo "     Add to .env:"
  echo "       ${env_prefix}_OAUTH_CLIENT_ID=${client_id}"
  echo "       ${env_prefix}_OAUTH_CLIENT_SECRET=${client_secret}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

create_groups() {
  log_info "Creating user groups..."

  for group in "homelab-admins" "homelab-users" "media-users"; do
    local payload
    payload=$(jq -n --arg name "${group}" '{"name": $name, "is_superuser": false}')
    api_post "/core/groups/" "${payload}" >/dev/null 2>&1 || \
      log_warn "Group ${group} may already exist"
    log_ok "Group: ${group}"
  done
}

create_forwardauth_outpost() {
  log_info "Creating Traefik ForwardAuth outpost..."

  local providers_list
  providers_list="[]"

  local payload
  payload=$(jq -n \
    --arg name "homelab-proxy" \
    '{
      name: $name,
      type: "proxy",
      providers: [],
      config: {
        authentik_host: ("https://auth." + (env.DOMAIN // "example.com")),
        authentik_host_insecure: false,
        log_level: "info",
        error_reporting: false
      }
    }')

  api_post "/outposts/instances/" "${payload}" >/dev/null 2>&1 || \
    log_warn "Outpost may already exist"

  log_ok "ForwardAuth outpost created: homelab-proxy"
  log_info "Add applications to the outpost in Authentik Admin UI:"
  log_info "  ${AUTHENTIK_URL}/if/admin/#/outpost/list"
}

# =============================================================================
# Main
# =============================================================================

echo "============================================================"
echo "  Authentik Setup Script"
echo "  Target: ${AUTHENTIK_URL}"
echo "  Mode: $(if [[ "${DRY_RUN}" == "true" ]]; then echo "DRY RUN"; else echo "LIVE"; fi)"
echo "============================================================"
echo ""

check_deps
wait_for_authentik
authenticate
get_or_create_flow

# Create groups first
if [[ -z "${TARGET_SERVICE}" ]]; then
  create_groups
fi

# Define all services
declare -A SERVICES
SERVICES=(
  ["grafana"]="Grafana|grafana|https://grafana.${DOMAIN}/login/generic_oauth|GRAFANA|Grafana monitoring dashboard"
  ["gitea"]="Gitea|gitea|https://gitea.${DOMAIN}/user/oauth2/authentik/callback|GITEA|Gitea Git hosting"
  ["nextcloud"]="Nextcloud|nextcloud|https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik|NEXTCLOUD|Nextcloud file storage"
  ["outline"]="Outline|outline|https://outline.${DOMAIN}/auth/oidc.callback|OUTLINE|Outline wiki"
  ["openwebui"]="Open WebUI|openwebui|https://chat.${DOMAIN}/oauth/oidc/callback|OPENWEBUI|Open WebUI AI chat"
  ["portainer"]="Portainer|portainer|https://portainer.${DOMAIN}|PORTAINER|Portainer Docker management"
)

# Process services
for service in "${!SERVICES[@]}"; do
  if [[ -n "${TARGET_SERVICE}" && "${service}" != "${TARGET_SERVICE}" ]]; then
    continue
  fi

  IFS='|' read -r app_name slug redirect_uri env_prefix description <<< "${SERVICES[${service}]}"
  setup_service "${service}" "${app_name}" "${slug}" "${redirect_uri}" "${env_prefix}" "${description}"
done

# Create ForwardAuth outpost
if [[ -z "${TARGET_SERVICE}" ]]; then
  echo ""
  create_forwardauth_outpost
fi

echo ""
echo "============================================================"
log_ok "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Copy the Client ID/Secret values above into .env"
echo "  2. Restart affected stacks:"
echo "       docker compose -f stacks/monitoring/docker-compose.yml restart"
echo "       docker compose -f stacks/productivity/docker-compose.yml restart"
echo "  3. Visit ${AUTHENTIK_URL}/if/admin/ to verify providers"
echo "  4. Test login on each service"
echo "============================================================"
