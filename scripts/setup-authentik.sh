#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services and sets up user groups
# Requires: curl, jq
# Usage:
#   ./scripts/setup-authentik.sh            # Run setup
#   ./scripts/setup-authentik.sh --dry-run  # Preview what would be created
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"

# Load .env from SSO directory first, then root
for env_file in "$SSO_DIR/.env" "$ROOT_DIR/.env"; do
  if [ -f "$env_file" ]; then
    set -a; source "$env_file"; set +a
  fi
done

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }

# Dry run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log_warn "Running in DRY-RUN mode -- no changes will be made"
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_error "Get it from: https://$AUTHENTIK_DOMAIN/-/admin/settings/#admin-token"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

# ------------------------------------------------------------------
# Helper: Wait for Authentik to be ready
# ------------------------------------------------------------------
wait_for_authentik() {
  log_step "Waiting for Authentik API..."
  for i in $(seq 1 30); do
    if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null; then
      log_info "Authentik is ready"
      return 0
    fi
    echo -n "."
    sleep 5
  done
  log_error "Authentik did not become ready in 150s"
  exit 1
}

# ------------------------------------------------------------------
# Helper: Get default flow by designation
# ------------------------------------------------------------------
get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

# ------------------------------------------------------------------
# Helper: Get signing key
# ------------------------------------------------------------------
get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk // empty'
}

# ------------------------------------------------------------------
# Helper: Create OIDC provider and application
# ------------------------------------------------------------------
create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  log_step "Creating OIDC provider: $name"
  echo "    Redirect URI: $redirect_uri"

  if $DRY_RUN; then
    log_dry "Would create provider: $name"
    log_dry "Would create application: $name"
    log_dry "Would set .env: $client_id_var=<AUTO> $client_secret_var=<AUTO>"
    return 0
  fi

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)

  if [ -z "$flow_pk" ] || [ -z "$signing_key" ]; then
    log_error "Could not get flow or signing key"
    return 1
  fi

  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

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

  local provider_pk client_id client_secret
  provider_pk=$(echo "$response" | jq -r '.pk')
  client_id=$(echo "$response" | jq -r '.client_id')
  client_secret=$(echo "$response" | jq -r '.client_secret')

  echo -e "    ${GREEN}Provider PK:${RESET} $provider_pk"
  echo -e "    ${GREEN}Client ID:${RESET}   $client_id"
  echo -e "    ${GREEN}Client Secret:${RESET} $client_secret"

  # Write to .env files
  for env_file in "$SSO_DIR/.env" "$ROOT_DIR/.env"; do
    if [ -f "$env_file" ]; then
      if grep -q "^${client_id_var}=" "$env_file" 2>/dev/null; then
        sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$env_file"
      fi
      if grep -q "^${client_secret_var}=" "$env_file" 2>/dev/null; then
        sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$env_file"
      fi
    fi
  done

  # Create application
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

  echo -e "    ${GREEN}[OK]${RESET} Application created: $name"
}

# ------------------------------------------------------------------
# Helper: Create user group
# ------------------------------------------------------------------
create_group() {
  local group_name="$1"

  if $DRY_RUN; then
    log_dry "Would create group: $group_name"
    return 0
  fi

  log_info "Creating group: $group_name"

  local payload
  payload=$(jq -n --arg name "$group_name" '{name: $name}')

  local response
  response=$(curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if echo "$response" | jq -e '.pk' > /dev/null 2>&1; then
    echo -e "    ${GREEN}[OK]${RESET} Group created: $group_name (pk: $(echo "$response" | jq -r '.pk'))"
  else
    # Group might already exist
    echo -e "    ${YELLOW}[SKIP]${RESET} Group already exists or error: $group_name"
  fi
}

# ------------------------------------------------------------------
# Main execution
# ------------------------------------------------------------------
main() {
  echo ""
  echo -e "${BOLD}========================================${RESET}"
  echo -e "${BOLD}Authentik SSO Setup${RESET}"
  echo -e "${BOLD}========================================${RESET}"

  # Wait for Authentik to be ready
  wait_for_authentik

  # ------------------------------------------------------------------
  # Create user groups
  # ------------------------------------------------------------------
  log_step "Creating User Groups"
  create_group "homelab-admins"
  create_group "homelab-users"
  create_group "media-users"

  # ------------------------------------------------------------------
  # Create OIDC providers
  # ------------------------------------------------------------------
  log_step "Creating OIDC Providers"

  # Grafana
  create_oidc_provider \
    "Grafana" \
    "https://grafana.${DOMAIN}/login/generic_oauth" \
    "GRAFANA_OAUTH_CLIENT_ID" \
    "GRAFANA_OAUTH_CLIENT_SECRET"

  # Gitea
  create_oidc_provider \
    "Gitea" \
    "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
    "GITEA_OAUTH_CLIENT_ID" \
    "GITEA_OAUTH_CLIENT_SECRET"

  # Outline
  create_oidc_provider \
    "Outline" \
    "https://outline.${DOMAIN}/auth/oidc.callback" \
    "OUTLINE_OAUTH_CLIENT_ID" \
    "OUTLINE_OAUTH_CLIENT_SECRET"

  # Portainer
  create_oidc_provider \
    "Portainer" \
    "https://portainer.${DOMAIN}/" \
    "PORTAINER_OAUTH_CLIENT_ID" \
    "PORTAINER_OAUTH_CLIENT_SECRET"

  # Nextcloud
  create_oidc_provider \
    "Nextcloud" \
    "https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik" \
    "NEXTCLOUD_OAUTH_CLIENT_ID" \
    "NEXTCLOUD_OAUTH_CLIENT_SECRET"

  # Open WebUI
  create_oidc_provider \
    "OpenWebUI" \
    "https://ai.${DOMAIN}/auth" \
    "OPEN_WEBUI_OAUTH_CLIENT_ID" \
    "OPEN_WEBUI_OAUTH_CLIENT_SECRET"

  # ------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------
  echo ""
  echo -e "${BOLD}========================================${RESET}"
  echo -e "${BOLD}Setup Complete!${RESET}"
  echo -e "${BOLD}========================================${RESET}"
  echo ""
  echo "Next steps:"
  echo "  1. Go to: https://$AUTHENTIK_URL"
  echo "  2. Login with: $AUTHENTIK_BOOTSTRAP_EMAIL"
  echo "  3. Verify the providers and applications were created"
  echo "  4. Update .env files in each stack with the Client ID/Secret"
  echo ""
  echo "OIDC issuer URL: $AUTHENTIK_URL/application/o/<slug>/"
  echo ""
}

main
