#!/usr/bin/env bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════
# Authentik Setup Script — Auto-provisions OIDC Providers + Apps
# ════════════════════════════════════════════════════════════════
# Usage:
#   ./scripts/authentik-setup.sh           # Run provisioning
#   ./scripts/authentik-setup.sh --dry-run  # Preview without changes
#
# Prerequisites:
#   - Authentik server running at https://auth.${DOMAIN}
#   - Authentik admin token set in AUTHENTIK_TOKEN env var
#   - jq installed
# ════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../stacks/sso/.env"
DRY_RUN=false
AUTHENTIK_URL="${AUTHENTIK_URL:-http://authentik-server:9000}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"

if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN MODE — no changes will be made ==="
  echo
fi

if [[ -z "$AUTHENTIK_TOKEN" ]]; then
  echo "ERROR: AUTHENTIK_TOKEN environment variable not set."
  echo "Generate a token in Authentik: Admin → Settings → Tokens → Create"
  echo "Export it: export AUTHENTIK_TOKEN=your-token-here"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install it first."
  exit 1
fi

# ── Helper Functions ────────────────────────────────────────────

api_get() {
  local path="$1"
  curl -sf -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
    "${AUTHENTIK_URL}/api/v3${path}" 2>/dev/null || echo "[]"
}

api_post() {
  local path="$1"
  local data="$2"
  if $DRY_RUN; then
    echo "  [DRY-RUN] Would POST to ${path}"
    echo "  [DRY-RUN] Data: ${data}"
    return 0
  fi
  curl -sf -X POST \
    -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$data" \
    "${AUTHENTIK_URL}/api/v3${path}" 2>/dev/null
}

create_group() {
  local name="$1"
  echo "  Creating group: ${name}"
  local existing
  existing=$(api_get "/core/groups/?name=${name}" | jq -r ".[0].pk // empty")
  if [[ -n "$existing" ]]; then
    echo "  [SKIP] Group already exists: ${name}"
    return 0
  fi
  api_post "/core/groups/" "{\"name\":\"${name}\"}"
  echo "  [OK] Created group: ${name}"
}

create_property_mapping() {
  local name="$1"
  local expression="$2"
  echo "  Creating property mapping: ${name}"
  local existing
  existing=$(api_get "/propertymappings/source/oauth/?name=${name}" | jq -r ".[0].pk // empty")
  if [[ -n "$existing" ]]; then
    echo "  [SKIP] Property mapping already exists: ${name}"
    return 0
  fi
  api_post "/propertymappings/source/oauth/" "{\"name\":\"${name}\",\"expression\":\"${expression}\"}"
  echo "  [OK] Created property mapping: ${name}"
}

# Creates an OAuth2 Provider + Application pair
# Args: service_name  redirect_uri  additional_scopes
create_oidc_provider() {
  local service="$1"
  local redirect="$2"
  local name="OIDC-${service}"
  local client_id="${service,,}-$(date +%s | tail -c 5)-$(openssl rand -hex 4 2>/dev/null || echo "random")"
  local client_secret
  client_secret=$(openssl rand -base64 32 2>/dev/null || echo "changeme-secret")

  echo
  echo "── ${service} ──────────────────────────────────────"

  # Check if provider already exists
  local existing
  existing=$(api_get "/oauth2/providers/?name=${name}" | jq -r ".[0].pk // empty")
  if [[ -n "$existing" ]]; then
    echo "  [SKIP] Provider already exists: ${name}"
    local existing_client_id
    existing_client_id=$(api_get "/oauth2/providers/?name=${name}" | jq -r ".[0].client_id // empty")
    echo "      Client ID: ${existing_client_id}"
    echo "      (Client Secret: hidden — check Authentik admin panel)"
    echo "      Redirect URI: ${redirect}"
    return 0
  fi

  local provider_data
  provider_data=$(cat <<EOF
{
  "name": "${name}",
  "authorization_flow": "default-provider-authorization-implicit-consent",
  "client_type": "confidential",
  "client_id": "${client_id}",
  "client_secret": "${client_secret}",
  "redirect_uris": ["${redirect}"],
  "access_code_validity": "minutes=5",
  "access_token_validity": "days=30",
  "refresh_token_validity": "days=30",
  "signing_key": "",
  "sub_mode": "hashed_user_id",
  "issuer_mode": "per_provider"
}
EOF
)

  local result
  result=$(api_post "/oauth2/providers/" "$provider_data")

  if [[ -z "$result" ]] && ! $DRY_RUN; then
    echo "  [ERROR] Failed to create provider for ${service}"
    return 1
  fi

  local provider_pk
  if $DRY_RUN; then
    provider_pk="dry-run-pk"
  else
    provider_pk=$(echo "$result" | jq -r ".pk // empty")
  fi

  echo "  [OK] Created provider: ${service}"
  echo "      Client ID: ${client_id}"
  echo "      Client Secret: ${client_secret}"
  echo "      Redirect URI: ${redirect}"

  # Create Application linked to this provider
  local app_data
  app_data=$(cat <<EOF
{
  "name": "${service}",
  "slug": "${service,,}",
  "provider": ${provider_pk:-null},
  "meta_launch_url": "",
  "policy_engine_mode": "any",
  "open_in_new_tab": false
}
EOF
)

  local app_existing
  app_existing=$(api_get "/core/applications/?slug=${service,,}" | jq -r ".[0].pk // empty")
  if [[ -n "$app_existing" ]]; then
    echo "  [SKIP] Application already exists: ${service}"
    return 0
  fi

  api_post "/core/applications/" "$app_data"
  echo "  [OK] Created application: ${service}"
}

# ════════════════════════════════════════════════════════════════
# 1. Create User Groups
# ════════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════"
echo "  Step 1: Creating User Groups"
echo "═══════════════════════════════════════════════════"

create_group "homelab-admins"
create_group "homelab-users"
create_group "homelab-media"
create_group "homelab-dev"

# ════════════════════════════════════════════════════════════════
# 2. Create OIDC Property Mappings
# ════════════════════════════════════════════════════════════════
echo
echo "═══════════════════════════════════════════════════"
echo "  Step 2: Creating OIDC Property Mappings"
echo "═══════════════════════════════════════════════════"

create_property_mapping "homelab-groups" "return [group.name for group in user.ak_groups.all()]"

# ════════════════════════════════════════════════════════════════
# 3. Create OIDC Providers + Applications
# ════════════════════════════════════════════════════════════════
echo
echo "═══════════════════════════════════════════════════"
echo "  Step 3: Creating OIDC Providers + Applications"
echo "═══════════════════════════════════════════════════"

DOMAIN="${DOMAIN:-example.com}"

create_oidc_provider "Grafana"      "https://grafana.${DOMAIN}/login/generic_oauth"
create_oidc_provider "Gitea"        "https://gitea.${DOMAIN}/user/oauth2/auth/callback"
create_oidc_provider "Nextcloud"    "https://nextcloud.${DOMAIN}/apps/oidc_login/oidc"
create_oidc_provider "Outline"      "https://outline.${DOMAIN}/auth/oidc.callback"
create_oidc_provider "OpenWebUI"    "https://ai.${DOMAIN}/oauth/oidc"
create_oidc_provider "Portainer"    "https://portainer.${DOMAIN}/"

# ════════════════════════════════════════════════════════════════
# 4. Summary
# ════════════════════════════════════════════════════════════════
echo
echo "═══════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "═══════════════════════════════════════════════════"
echo
echo "Next steps:"
echo "  1. Copy the Client ID + Client Secret for each service"
echo "  2. Paste them into the corresponding .env files:"
echo "     - stacks/sso/.env (for Authentik core settings)"
echo "     - stacks/observability/.env (Grafana OIDC)"
echo "     - stacks/productivity/.env (Gitea, Outline OIDC)"
echo "     - stacks/storage/.env (Nextcloud OIDC)"
echo "     - stacks/ai/.env (Open WebUI OIDC)"
echo "     - stacks/base/.env (Portainer OAuth)"
echo "  3. Restart affected services: docker compose up -d"
echo
if $DRY_RUN; then
  echo "NOTE: This was a dry run. Run without --dry-run to apply changes."
fi