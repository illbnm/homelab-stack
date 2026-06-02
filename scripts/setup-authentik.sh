#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for: Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
#
# ARM64 compatible — works on ARM64 (DGX Atom, Raspberry Pi) and x86_64.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [[ "$DRY_RUN" == true ]]; then
  log_step "DRY RUN MODE — no changes will be made"
  echo ""
  cat << 'DRYEOF'
The following OIDC providers would be created:
  ┌────────────┬──────────────────────────────────────────────────┐
  │ Provider   │ Redirect URI                                     │
  ├────────────┼──────────────────────────────────────────────────┤
  │ Grafana    │ https://grafana.DOMAIN/login/generic_oauth       │
  │ Gitea      │ https://git.DOMAIN/user/oauth2/Authentik/callback│
  │ Nextcloud  │ https://nextcloud.DOMAIN/apps/sociallogin/...    │
  │ Outline    │ https://outline.DOMAIN/auth/oidc.callback        │
  │ Open WebUI │ https://ai.DOMAIN/oauth/oidc/callback            │
  │ Portainer  │ https://portainer.DOMAIN/                        │
  └────────────┴──────────────────────────────────────────────────┘

Credentials would be written to: .env
Environment variables updated:
  GRAFANA_OAUTH_CLIENT_ID, GRAFANA_OAUTH_CLIENT_SECRET
  GITEA_OAUTH_CLIENT_ID, GITEA_OAUTH_CLIENT_SECRET
  NEXTCLOUD_OAUTH_CLIENT_ID, NEXTCLOUD_OAUTH_CLIENT_SECRET
  OUTLINE_OAUTH_CLIENT_ID, OUTLINE_OAUTH_CLIENT_SECRET
  WEBUI_OAUTH_CLIENT_ID, WEBUI_OAUTH_CLIENT_SECRET
  PORTAINER_OAUTH_CLIENT_ID, PORTAINER_OAUTH_CLIENT_SECRET

OIDC Issuer URL:  $AUTHENTIK_URL/application/o/<slug>/
OpenID Config:    $AUTHENTIK_URL/application/o/<slug>/.well-known/openid-configuration
DRYEOF
  exit 0
fi

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
  log_info "Generate one with: openssl rand -hex 32"
  log_info "Then add to .env: AUTHENTIK_BOOTSTRAP_TOKEN=<value>"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

get_default_flow() {
  local designation="$1"
  curl -sf "$API_URL/flows/instances/?designation=${designation}&ordering=slug" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
}

get_signing_key() {
  curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" \
    -H "$AUTH_HEADER" | jq -r '.results[0].pk'
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

  log_info "  Provider PK: $provider_pk"
  log_ok   "  Client ID:   $client_id"
  log_info "  Client Secret: $client_secret"
  log_info "  Redirect URI:  $redirect_uri"

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

  log_info "  Application created: $name"
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
log_step "Waiting for Authentik API..."
for i in $(seq 1 30); do
  if curl -sf "$AUTHENTIK_URL/-/health/ready/" -o /dev/null 2>/dev/null; then
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

# ------------------------------------------------------------------
# Create providers for all services
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
  "WEBUI_OAUTH_CLIENT_ID" \
  "WEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

log_step "All 6 providers created. Credentials written to $ROOT_DIR/.env"
log_info "Authentik OIDC issuer:  $AUTHENTIK_URL/application/o/<slug>/"
log_info "OpenID Configuration:  $AUTHENTIK_URL/application/o/<slug>/.well-known/openid-configuration"
echo ""
log_info "Next steps:"
echo "  1. Configure Grafana OIDC in stacks/monitoring/.env"
echo "  2. Configure Gitea OIDC in stacks/productivity/.env"
echo "  3. Run ./scripts/nextcloud-oidc-setup.sh for Nextcloud"
echo "  4. Configure Open WebUI OIDC in stacks/ai/.env"
echo "  5. Configure Portainer OAuth in Portainer UI admin"
