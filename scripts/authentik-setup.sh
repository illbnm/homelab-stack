#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
# Requires: curl, jq
# Usage: ./scripts/authentik-setup.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log_warn "Running in DRY-RUN mode. No changes will be made to Authentik."
fi

DOMAIN="${DOMAIN:-example.com}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

# In dry-run, we don't strictly require the bootstrap token
if [[ "$DRY_RUN" == "false" && -z "$TOKEN" ]]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

get_default_flow() {
  local designation="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "mock-flow-pk"
    return
  fi
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "mock-signing-key-pk"
    return
  fi
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  if [[ "$DRY_RUN" == "true" ]]; then
    local mock_client_id="mock-client-id-for-${slug}-123456789"
    local mock_client_secret="mock-client-secret-for-${slug}-abcdefghijklmnopqrstuvwxyz"
    echo -e "${GREEN}[OK]${RESET} Created provider: ${BOLD}${name}${RESET}"
    echo "     Client ID:     $mock_client_id"
    echo "     Client Secret: $mock_client_secret"
    echo "     Redirect URI:  $redirect_uri"
    return
  fi

  log_step "Creating OIDC provider: $name"

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
      signing_key: $key
    }')

  # Check if provider already exists
  local existing_provider_pk=""
  local check_res
  check_res=$(curl -sf "$API_URL/providers/oauth2/?search=${name}+Provider" -H "$AUTH_HEADER")
  if [[ -n "$check_res" ]]; then
    existing_provider_pk=$(echo "$check_res" | jq -r '.results[] | select(.name == "\($name) Provider") | .pk' 2>/dev/null || echo "")
  fi

  local provider_pk client_id client_secret
  if [[ -n "$existing_provider_pk" ]]; then
    log_info "  Provider already exists (PK: $existing_provider_pk). Re-using client details..."
    client_id=$(echo "$check_res" | jq -r ".results[] | select(.pk == $existing_provider_pk) | .client_id")
    client_secret=$(echo "$check_res" | jq -r ".results[] | select(.pk == $existing_provider_pk) | .client_secret")
    provider_pk="$existing_provider_pk"
  else
    local response
    response=$(curl -sf -X POST "$API_URL/providers/oauth2/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$payload")

    provider_pk=$(echo "$response" | jq -r '.pk')
    client_id=$(echo "$response" | jq -r '.client_id')
    client_secret=$(echo "$response" | jq -r '.client_secret')
  fi

  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"

  # Update root .env safely
  if grep -q "^${client_id_var}=" "$ROOT_DIR/.env"; then
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
  else
    echo "${client_id_var}=${client_id}" >> "$ROOT_DIR/.env"
  fi

  if grep -q "^${client_secret_var}=" "$ROOT_DIR/.env"; then
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
  else
    echo "${client_secret_var}=${client_secret}" >> "$ROOT_DIR/.env"
  fi

  # Check if application already exists
  local app_check
  app_check=$(curl -sf "$API_URL/core/applications/?search=${name}" -H "$AUTH_HEADER")
  local app_exists
  app_exists=$(echo "$app_check" | jq -r --arg slug "$slug" '.results[] | select(.slug == $slug) | .slug' 2>/dev/null || echo "")

  if [[ -n "$app_exists" ]]; then
    log_info "  Application already exists for slug '$slug'. Skipping creation."
  else
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
  fi
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
if [[ "$DRY_RUN" == "false" ]]; then
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
# Create providers
# ------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "\n${BOLD}${CYAN}==> Simulated Setup Preview:${RESET}"
fi

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
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Open WebUI" \
  "https://ai.${DOMAIN}/oauth/oidc/callback" \
  "OPEN_WEBUI_OAUTH_CLIENT_ID" \
  "OPEN_WEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

if [[ "$DRY_RUN" == "false" ]]; then
  log_step "All providers created. Credentials written to .env"
  log_info "Authentik OIDC issuer: $AUTHENTIK_URL/application/o/<slug>/"
fi
