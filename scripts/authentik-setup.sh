#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for Grafana, Gitea, Outline, Portainer, Nextcloud, Open WebUI
# =============================================================================
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  echo "[INFO] Running in dry-run mode. No changes will be made."
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.example.com}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-dummy}"

AUTH_HEADER="Authorization: Bearer $TOKEN"

create_oidc_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id_var="$3"
  local client_secret_var="$4"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[OK] Created provider: $name"
    echo "     Client ID: dry_run_client_id_xxxxx"
    echo "     Client Secret: dry_run_client_secret_xxxxx"
    echo "     Redirect URI: $redirect_uri"
    return
  fi

  local flow_pk=$(curl -sf "$API_URL/flows/instances/?designation=authorize&ordering=slug" -H "$AUTH_HEADER" | jq -r '.results[0].pk')
  local signing_key=$(curl -sf "$API_URL/crypto/certificatekeypairs/?has_key=true&ordering=name" -H "$AUTH_HEADER" | jq -r '.results[0].pk')
  local slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

  local payload=$(jq -n --arg name "${name} Provider" --arg flow "$flow_pk" --arg uri "$redirect_uri" --arg key "$signing_key" '{name: $name, authorization_flow: $flow, client_type: "confidential", redirect_uris: $uri, sub_mode: "hashed_user_id", include_claims_in_id_token: true, signing_key: $key}')

  local response=$(curl -sf -X POST "$API_URL/providers/oauth2/" -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$payload")

  local provider_pk=$(echo "$response" | jq -r '.pk')
  local client_id=$(echo "$response" | jq -r '.client_id')
  local client_secret=$(echo "$response" | jq -r '.client_secret')

  if [ -f "$ROOT_DIR/.env" ]; then
    sed -i '' "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i '' "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
  fi

  local app_payload=$(jq -n --arg name "$name" --arg slug "$slug" --argjson pk "$provider_pk" '{name: $name, slug: $slug, provider: $pk}')
  curl -sf -X POST "$API_URL/core/applications/" -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$app_payload" > /dev/null

  echo "[OK] Created provider: $name"
  echo "     Client ID: $client_id"
  echo "     Client Secret: $client_secret"
  echo "     Redirect URI: $redirect_uri"
}

create_oidc_provider "Grafana" "https://grafana.${DOMAIN:-example.com}/login/generic_oauth" "GRAFANA_OAUTH_CLIENT_ID" "GRAFANA_OAUTH_CLIENT_SECRET"
create_oidc_provider "Gitea" "https://git.${DOMAIN:-example.com}/user/oauth2/Authentik/callback" "GITEA_OAUTH_CLIENT_ID" "GITEA_OAUTH_CLIENT_SECRET"
create_oidc_provider "Nextcloud" "https://nextcloud.${DOMAIN:-example.com}/apps/oidc_login/oidc" "NEXTCLOUD_OAUTH_CLIENT_ID" "NEXTCLOUD_OAUTH_CLIENT_SECRET"
create_oidc_provider "Outline" "https://docs.${DOMAIN:-example.com}/auth/oidc.callback" "OUTLINE_OAUTH_CLIENT_ID" "OUTLINE_OAUTH_CLIENT_SECRET"
create_oidc_provider "Open WebUI" "https://ai.${DOMAIN:-example.com}/oauth/oidc/callback" "OPENWEBUI_OAUTH_CLIENT_ID" "OPENWEBUI_OAUTH_CLIENT_SECRET"
create_oidc_provider "Portainer" "https://portainer.${DOMAIN:-example.com}/" "PORTAINER_OAUTH_CLIENT_ID" "PORTAINER_OAUTH_CLIENT_SECRET"
