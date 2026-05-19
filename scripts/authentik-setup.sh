#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
# Supports --dry-run, safe credential output, user groups, and idempotency.
# Usage: ./scripts/authentik-setup.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env from root
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Dry-run flag
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  log_warn "DRY-RUN MODE ENABLED - No changes will be applied to Authentik"
fi

DOMAIN="${DOMAIN:-example.com}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

# Check for required tools
for cmd in curl jq; do
  if ! command -v "$cmd" &> /dev/null; then
    log_error "Required tool '$cmd' is not installed."
    exit 1
  fi
done

# If no token, attempt to authenticate using bootstrap credentials
if [ -z "$TOKEN" ] && [ -n "${AUTHENTIK_BOOTSTRAP_PASSWORD:-}" ]; then
  if [ "$DRY_RUN" = "true" ]; then
    log_info "Dry-run: Would attempt to authenticate using bootstrap password"
    TOKEN="dry-run-token"
  else
    log_info "No AUTHENTIK_BOOTSTRAP_TOKEN found. Attempting login to get token..."
    LOGIN_RESP=$(curl -sf -X POST "$API_URL/admin/token/" \
      -H "Content-Type: application/json" \
      -d "{\"username\": \"akadmin\", \"password\": \"${AUTHENTIK_BOOTSTRAP_PASSWORD}\"}" || true)
    if [ -n "$LOGIN_RESP" ]; then
      TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')
    fi
  fi
fi

if [ -z "$TOKEN" ] && [ "$DRY_RUN" = "false" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN or AUTHENTIK_BOOTSTRAP_PASSWORD must be set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
if [ "$DRY_RUN" = "false" ]; then
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

get_default_flow() {
  local designation="$1"
  if [ "$DRY_RUN" = "true" ]; then
    echo "dry-run-flow-pk"
    return
  fi
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

get_signing_key() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "dry-run-key-pk"
    return
  fi
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

# ------------------------------------------------------------------
# Group Creation (homelab-admins, homelab-users, media-users)
# ------------------------------------------------------------------
create_group() {
  local name="$1"
  log_step "Checking/Creating Group: $name"
  
  if [ "$DRY_RUN" = "true" ]; then
    log_info "Dry-run: Would check/create group '$name'"
    return
  fi

  local existing
  existing=$(curl -sf "$API_URL/core/groups/?name=${name}" -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty')
  if [ -n "$existing" ]; then
    log_info "Group '$name' already exists (PK: $existing)"
  else
    local payload
    payload=$(jq -n --arg name "$name" '{name: $name}')
    local response
    response=$(curl -sf -X POST "$API_URL/core/groups/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$payload")
    local new_pk
    new_pk=$(echo "$response" | jq -r '.pk')
    log_info "Group '$name' created successfully (PK: $new_pk)"
  fi
}

create_group "homelab-admins"
create_group "homelab-users"
create_group "media-users"

# ------------------------------------------------------------------
# OIDC Provider & Application Creation
# ------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Setup OIDC provider: $name"

  if [ "$DRY_RUN" = "true" ]; then
    log_info "Dry-run: Would create OIDC Provider for '$name'"
    log_info "  Redirect URI:  $redirect_uri"
    log_info "  Client ID Var: $client_id_var"
    log_info "  Client Sec Var: $client_secret_var"
    return
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  # Idempotence check: check if provider already exists by name
  local existing_provider_pk existing_client_id existing_client_secret
  local existing_provider_resp
  existing_provider_resp=$(curl -sf "$API_URL/providers/oauth2/?name=${name}%20Provider" -H "$AUTH_HEADER" || true)
  
  if [ -n "$existing_provider_resp" ] && [ "$(echo "$existing_provider_resp" | jq -r '.results | length')" -gt 0 ]; then
    existing_provider_pk=$(echo "$existing_provider_resp" | jq -r '.results[0].pk')
    existing_client_id=$(echo "$existing_provider_resp" | jq -r '.results[0].client_id')
    existing_client_secret=$(echo "$existing_provider_resp" | jq -r '.results[0].client_secret')
    log_info "  Provider '${name} Provider' already exists (PK: $existing_provider_pk)"
  else
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
    response=$(curl -sf -X POST "$API_URL/providers/oauth2/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$payload")

    existing_provider_pk=$(echo "$response" | jq -r '.pk')
    existing_client_id=$(echo "$response" | jq -r '.client_id')
    existing_client_secret=$(echo "$response" | jq -r '.client_secret')
    log_info "  Provider created successfully (PK: $existing_provider_pk)"
  fi

  # Idempotence check: check if application already exists by slug
  local existing_app
  existing_app=$(curl -sf "$API_URL/core/applications/?slug=${slug}" -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty')
  if [ -n "$existing_app" ]; then
    log_info "  Application '$name' already exists (PK: $existing_app)"
  else
    local app_payload
    app_payload=$(jq -n \
      --arg name "$name" \
      --arg slug "$slug" \
      --argjson pk "$existing_provider_pk" \
      '{name: $name, slug: $slug, provider: $pk}')

    curl -sf -X POST "$API_URL/core/applications/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$app_payload" > /dev/null
    log_info "  Application created successfully: $name"
  fi

  # Write back credentials safely to root .env if it exists
  if [ -f "$ROOT_DIR/.env" ]; then
    if grep -q "^${client_id_var}=" "$ROOT_DIR/.env"; then
      sed -i "s|^${client_id_var}=.*|${client_id_var}=${existing_client_id}|" "$ROOT_DIR/.env"
    else
      echo "${client_id_var}=${existing_client_id}" >> "$ROOT_DIR/.env"
    fi

    if grep -q "^${client_secret_var}=" "$ROOT_DIR/.env"; then
      sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${existing_client_secret}|" "$ROOT_DIR/.env"
    else
      echo "${client_secret_var}=${existing_client_secret}" >> "$ROOT_DIR/.env"
    fi
  fi

  # Display safe credentials to console
  echo -e "  -------------------------------------------------"
  echo -e "  [OK] Created/Verified provider: ${BOLD}$name${RESET}"
  echo -e "       Client ID:     ${GREEN}$existing_client_id${RESET}"
  echo -e "       Client Secret: ${YELLOW}$existing_client_secret${RESET}"
  echo -e "       Redirect URI:  $redirect_uri"
  echo -e "  -------------------------------------------------"
}

# ------------------------------------------------------------------
# Define all OIDC Providers
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
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/index.php/apps/sociallogin/custom_oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Outline" \
  "https://docs.${DOMAIN}/auth/oidc.callback" \
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

log_step "All OIDC/OAuth Providers checked/configured successfully!"
if [ "$DRY_RUN" = "false" ]; then
  log_info "Credentials have been automatically written to the root .env file."
fi
