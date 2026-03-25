#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services + user groups
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh
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
log_ok()    { echo -e "${GREEN}[✓]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# =============================================================================
# Helper Functions
# =============================================================================

get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

get_or_create_group() {
  local group_name="$1"
  
  # Check if group exists
  local existing
  existing=$(curl -sf "$API_URL/core/groups/?name=${group_name}" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty')
  
  if [ -n "$existing" ]; then
    log_info "  Group exists: $group_name ($existing)"
    echo "$existing"
    return
  fi
  
  # Create group
  local response
  response=$(curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${group_name}\"}")
  
  local pk
  pk=$(echo "$response" | jq -r '.pk // empty')
  log_ok "  Group created: $group_name ($pk)"
  echo "$pk"
}

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  if [ -z "$flow_pk" ]; then
    log_error "  Could not find authorization flow"
    return 1
  fi
  
  if [ -z "$signing_key" ]; then
    log_error "  Could not find signing key"
    return 1
  fi

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
      redirect_uris: [$uri],
      sub_mode: "hashed_user_id",
      issuer_mode: "per_provider",
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
  client_secret=$(echo "$response" | jq -r '.client_secret // ""')

  log_info "  Provider PK: $provider_pk"
  log_info "  Client ID:   $client_id"
  if [ -n "$client_secret" ]; then
    log_info "  Client Secret: $client_secret"
  fi

  # Write to .env if variable names provided
  if [ -n "$client_id_var" ]; then
    if grep -q "^${client_id_var}=" "$ROOT_DIR/.env" 2>/dev/null; then
      sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    else
      echo "${client_id_var}=${client_id}" >> "$ROOT_DIR/.env"
    fi
  fi
  
  if [ -n "$client_secret_var" ] && [ -n "$client_secret" ]; then
    if grep -q "^${client_secret_var}=" "$ROOT_DIR/.env" 2>/dev/null; then
      sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
    else
      echo "${client_secret_var}=${client_secret}" >> "$ROOT_DIR/.env"
    fi
  fi

  # Create Application
  local app_payload
  app_payload=$(jq -n \
    --arg name "$name" \
    --arg slug "$slug" \
    --argjson pk "$provider_pk" \
    --arg open_url "${redirect_uri%/callback*}" \
    '{name: $name, slug: $slug, provider: $pk, open_url: $open_url}')

  curl -sf -X POST "$API_URL/core/applications/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$app_payload" > /dev/null

  log_ok "  Application created: $name"
  log_info "  Redirect URI: $redirect_uri"
}

# =============================================================================
# Main
# =============================================================================

log_step "Authentik SSO Setup"
log_info "URL: $AUTHENTIK_URL"

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
log_step "Waiting for Authentik API..."
for i in $(seq 1 30); do
  if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null; then
    log_ok "Authentik is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    log_error "Authentik did not become ready in 150s"
    exit 1
  fi
  echo -n "."
  sleep 5
done

# ------------------------------------------------------------------
# Create User Groups
# ------------------------------------------------------------------
log_step "Creating user groups..."
ADMIN_GROUP=$(get_or_create_group "homelab-admins")
USER_GROUP=$(get_or_create_group "homelab-users")
MEDIA_GROUP=$(get_or_create_group "media-users")

log_ok "All groups created:"
log_info "  - homelab-admins ($ADMIN_GROUP) - Full access"
log_info "  - homelab-users ($USER_GROUP) - Standard access"
log_info "  - media-users ($MEDIA_GROUP) - Media only"

# ------------------------------------------------------------------
# Create OIDC Providers
# ------------------------------------------------------------------
log_step "Creating OIDC providers..."
echo ""
printf "${BOLD}%-15s | %-40s | %-30s${RESET}\n" "服务" "Client ID" "Redirect URI"
echo "--------------------------------------------------------------------------------"

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
  "https://cloud.${DOMAIN}/apps/sociallogin/custom/oidc/Authentik" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Outline" \
  "https://outline.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Open WebUI" \
  "https://webui.${DOMAIN}/oidc/callback" \
  "OPENWEBUI_OAUTH_CLIENT_ID" \
  "OPENWEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
log_step "Setup Complete!"
echo ""
log_ok "All OIDC providers created successfully"
log_info "Credentials written to: $ROOT_DIR/.env"
echo ""
log_info "Next steps:"
echo "  1. Review $ROOT_DIR/.env for Client IDs and Secrets"
echo "  2. Configure each service with its OIDC credentials"
echo "  3. In Authentik UI, configure Policy Bindings for each Application"
echo "  4. Assign users to appropriate groups (homelab-admins, homelab-users, media-users)"
echo ""
log_info "Authentik OIDC issuer format:"
echo "  https://${AUTHENTIK_DOMAIN}/application/o/<slug>/"
echo ""
log_info "Traefik ForwardAuth middleware URL:"
echo "  http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
