#!/bin/bash
# =============================================
# setup-authentik.sh - Auto configure OIDC providers
# =============================================
# This script:
# 1. Waits for Authentik to be ready
# 2. Creates OIDC providers for all integrated services
# 3. Writes client credentials to the shared .env (repo root)
# =============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables from SSO stack .env
SSO_ENV_FILE="${REPO_ROOT}/stacks/sso/.env"
if [ ! -f "${SSO_ENV_FILE}" ]; then
  echo "❌ SSO .env file not found at ${SSO_ENV_FILE}"
  echo "Please copy stacks/sso/.env.example to stacks/sso/.env and fill required values."
  exit 1
fi

set -a
source "${SSO_ENV_FILE}"
set +a

# Also load root .env to potentially update it
ROOT_ENV_FILE="${REPO_ROOT}/.env"
if [ ! -f "${ROOT_ENV_FILE}" ]; then
  echo "⚠️  Root .env not found at ${ROOT_ENV_FILE}, creating empty one."
  touch "${ROOT_ENV_FILE}"
fi

# --- Helper functions ---

wait_for_authentik() {
  local max_attempts=60
  local attempt=1
  local url="http://authentik-server:9000/-/health/ready/"

  echo "⏳ Waiting for Authentik to be ready..."
  while [ $attempt -le $max_attempts ]; do
    if curl -sf "${url}" > /dev/null 2>&1; then
      echo "✅ Authentik is ready (attempt $attempt)"
      return 0
    fi
    echo "   Attempt $attempt/${max_attempts}... waiting 5s"
    sleep 5
    attempt=$((attempt + 1))
  done
  echo "❌ Authentik did not become ready after ${max_attempts} attempts."
  exit 1
}

get_admin_token() {
  # Obtain admin bearer token using bootstrap token
  local token_url="https://${AUTHENTIK_DOMAIN}/api/v3/core/tokens/"
  local response
  response=$(curl -sf -X POST "${token_url}" \
    -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "identifier": "setup-script-token",
      "intent": "api",
      "expires": "2050-01-01T00:00:00Z"
    }' 2>/dev/null || true)
  
  if [ -z "${response}" ]; then
    # Fallback: use bootstrap token directly (it's already a valid API token)
    echo "${AUTHENTIK_BOOTSTRAP_TOKEN}"
  else
    echo "${response}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4
  fi
}

create_oidc_provider() {
  local service_name="$1"   # e.g. "grafana"
  local redirect_uri="$2"  # e.g. "https://grafana.example.com/login/generic_oauth"
  local client_id_var="${service_name}_oauth_client_id"
  local client_secret_var="${service_name}_oauth_client_secret"
  
  # Generate random ID and secret
  local client_id="${service_name}-$(openssl rand -hex 8)"
  local client_secret=$(openssl rand -hex 32)
  
  echo "🔧 Creating OIDC provider for ${service_name}..."
  
  local provider_url="https://${AUTHENTIK_DOMAIN}/api/v3/providers/oauth2/"
  local response
  response=$(curl -sf -X POST "${provider_url}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${service_name} Provider\",
      \"client_id\": \"${client_id}\",
      \"client_secret\": \"${client_secret}\",
      \"redirect_uris\": [\"${redirect_uri}\"],
      \"authorization_flow\": null,
      \"property_mappings\": [],
      \"client_type\": \"confidential\",
      \"access_code_validity\": \"minutes=5\",
      \"access_token_validity\": \"minutes=60\",
      \"refresh_token_validity\": \"days=30\",
      \"include_claims_from_id_token\": true,
      \"sub_mode\": \"hashed_user_id\"
    }" 2>/dev/null || { echo "⚠️  Failed to create provider for ${service_name}"; return 1; })
  
  # Extract provider ID from response (not strictly needed but useful)
  local provider_id
  provider_id=$(echo "${response}" | grep -o '"pk":[0-9]*' | cut -d: -f2)
  echo "   ✅ Provider created with ID: ${provider_id}"
  
  # Write credentials to root .env (if not already exists)
  if grep -q "^${client_id_var}=" "${ROOT_ENV_FILE}" 2>/dev/null; then
    echo "   ⚠️  ${client_id_var} already exists in root .env, skipping update."
  else
    echo "${client_id_var}=${client_id}" >> "${ROOT_ENV_FILE}"
    echo "${client_secret_var}=${client_secret}" >> "${ROOT_ENV_FILE}"
    echo "   ✅ Credentials written to root .env"
  fi
}

# --- Main ---

echo "================================================"
echo " Authentik OIDC Provider Setup Script"
echo "================================================"

# Ensure Authentik is running
wait_for_authentik

# Obtain admin token
ADMIN_TOKEN=$(get_admin_token)
if [ -z "${ADMIN_TOKEN}" ]; then
  echo "❌ Failed to obtain admin token. Check AUTHENTIK_BOOTSTRAP_TOKEN."
  exit 1
fi

echo "🔑 Admin token obtained successfully."

# Define services with their OIDC redirect URIs
# Format: "service_name|redirect_uri"
declare -a services=(
  "grafana|https://grafana.${DOMAIN}/login/generic_oauth"
  "gitea|https://git.${DOMAIN}/user/oauth2/authentik/callback"
  "outline|https://docs.${DOMAIN}/auth/oidc.callback"
  "portainer|https://portainer.${DOMAIN}/oauth/authorize"
  "nextcloud|https://nextcloud.${DOMAIN}/apps/oauth2/authorize"
)

for entry in "${services[@]}"; do
  IFS='|' read -r name redirect <<< "${entry}"
  create_oidc_provider "${name}" "${redirect}"
done

echo "================================================"
echo "✅ All OIDC providers configured."
echo "   Please restart affected services to load new credentials."
echo "   (e.g., docker compose -f stacks/monitoring/docker-compose.yml restart grafana)"
echo "================================================"
