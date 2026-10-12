#!/bin/bash

# Authentik Setup Script
# Automates the creation of OAuth2/OIDC Providers and Applications in Authentik.

set -euo pipefail

# --- Configuration ---
AUTHENTIK_HOST="https://auth.${DOMAIN}" # Will be replaced by .env DOMAIN
AUTHENTIK_ADMIN_USERNAME="${AUTHENTIK_BOOTSTRAP_EMAIL}" # From .env
AUTHENTIK_ADMIN_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD}" # From .env

# Services to configure
# Format: "Service Name|Redirect URI|Scopes (space-separated)|Provider Type (oauth2 or openid)"
# Note: For OpenID, 'openid profile email' are common scopes.
# For OAuth2, scopes might be simpler or not explicitly needed for basic auth.
# Authentik's OAuth2 provider is essentially OIDC without requiring 'openid' scope.
# We'll use 'openid' for all OIDC integrations.
SERVICES=(
  "Grafana|https://grafana.${DOMAIN}/login/generic_oauth|openid profile email|openid"
  "Gitea|https://gitea.${DOMAIN}/user/oauth2/authentik/callback|openid profile email|openid"
  "Nextcloud|https://cloud.${DOMAIN}/apps/sociallogin/oauth/authentik|openid profile email|openid"
  "Outline|https://outline.${DOMAIN}/auth/oidc.callback|openid profile email|openid"
  "Open WebUI|https://webui.${DOMAIN}/auth/callback|openid profile email|openid"
  "Portainer|https://portainer.${DOMAIN}/api/oauth/callback|openid profile email|oauth2" # Portainer uses OAuth2
)

# Groups to create
GROUPS=(
  "homelab-admins"
  "homelab-users"
  "media-users"
)

# --- Helper Functions ---

log_info() {
  echo "[INFO] $1"
}

log_success() {
  echo "[OK] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Function to get Authentik API token
get_authentik_token() {
  local username="$1"
  local password="$2"
  local host="$3"

  log_info "Attempting to get Authentik API token..."
  TOKEN_RESPONSE=$(curl -s -X POST "${host}/api/v3/auth/token/" \
    -H "Content-Type: application/json" \
    --data-raw "{\"username\": \"${username}\", \"password\": \"${password}\"}")

  if echo "${TOKEN_RESPONSE}" | jq -e '.access_token' > /dev/null; then
    echo "${TOKEN_RESPONSE}" | jq -r '.access_token'
  else
    log_error "Failed to get Authentik API token. Response: ${TOKEN_RESPONSE}"
  fi
}

# Function to wait for Authentik to be healthy
wait_for_authentik() {
  local host="$1"
  log_info "Waiting for Authentik to be healthy at ${host}..."
  for i in $(seq 1 60); do
    if curl -s -k "${host}/health/" | grep -q '"status": "healthy"'; then
      log_success "Authentik is healthy."
      return 0
    fi
    echo -n "."
    sleep 5
  done
  log_error "Authentik did not become healthy within the timeout."
}

# Function to create a group
create_group() {
  local group_name="$1"
  local token="$2"
  local host="$3"

  log_info "Creating group: ${group_name}"
  GROUP_RESPONSE=$(curl -s -X POST "${host}/api/v3/core/groups/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    --data-raw "{\"name\": \"${group_name}\"}")

  if echo "${GROUP_RESPONSE}" | jq -e '.pk' > /dev/null; then
    log_success "Group '${group_name}' created (PK: $(echo "${GROUP_RESPONSE}" | jq -r '.pk')). If it already existed, this might return an existing PK."
  else
    # Check if group already exists (Authentik returns 400 with 'name' error)
    if echo "${GROUP_RESPONSE}" | grep -q "A group with this name already exists"; then
      log_info "Group '${group_name}' already exists."
    else
      log_error "Failed to create group '${group_name}'. Response: ${GROUP_RESPONSE}"
    fi
  fi
}

# Function to create an OAuth2/OpenID Provider
create_provider() {
  local name="$1"
  local redirect_uri="$2"
  local scopes="$3"
  local provider_type="$4" # "oauth2" or "openid"
  local token="$5"
  local host="$6"

  log_info "Creating ${provider_type} provider: ${name}"

  local provider_data
  if [ "$provider_type" == "openid" ]; then
    provider_data=$(cat <<EOF
{
  "name": "${name}",
  "authorization_flow": "default-provider-authorization-explicit-consent",
  "client_type": "public",
  "redirect_uris": ["${redirect_uri}"],
  "jwks_uri": "",
  "sub_mode": "hashed_user_id",
  "access_token_validity": "minutes=30",
  "refresh_token_validity": "days=30",
  "include_claims_in_id_token": true,
  "signing_key": null,
  "oidc_scopes": ["${scopes// /,}"],
  "issuer_mode": "global"
}
EOF
)
  elif [ "$provider_type" == "oauth2" ]; then
    provider_data=$(cat <<EOF
{
  "name": "${name}",
  "authorization_flow": "default-provider-authorization-explicit-consent",
  "client_type": "public",
  "redirect_uris": ["${redirect_uri}"],
  "jwks_uri": "",
  "sub_mode": "hashed_user_id",
  "access_token_validity": "minutes=30",
  "refresh_token_validity": "days=30",
  "include_claims_in_id_token": true,
  "signing_key": null,
  "issuer_mode": "global"
}
EOF
)
  else
    log_error "Unsupported provider type: ${provider_type}"
  fi

  PROVIDER_RESPONSE=$(curl -s -X POST "${host}/api/v3/providers/${provider_type}/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    --data-raw "${provider_data}")

  if echo "${PROVIDER_RESPONSE}" | jq -e '.pk' > /dev/null; then
    echo "${PROVIDER_RESPONSE}"
  else
    # Check if provider already exists (Authentik returns 400 with 'name' error)
    if echo "${PROVIDER_RESPONSE}" | grep -q "A provider with this name already exists"; then
      log_info "Provider '${name}' already exists. Fetching existing details."
      EXISTING_PROVIDER=$(curl -s -X GET "${host}/api/v3/providers/${provider_type}/?name=${name}" \
        -H "Authorization: Bearer ${token}" | jq '.[0]')
      if echo "${EXISTING_PROVIDER}" | jq -e '.pk' > /dev/null; then
        echo "${EXISTING_PROVIDER}"
      else
        log_error "Failed to fetch existing provider '${name}'. Response: ${EXISTING_PROVIDER}"
      fi
    else
      log_error "Failed to create provider '${name}'. Response: ${PROVIDER_RESPONSE}"
    fi
  fi
}

# Function to create an Application
create_application() {
  local name="$1"
  local slug="$2"
  local provider_pk="$3"
  local token="$4"
  local host="$5"

  log_info "Creating application: ${name}"
  APP_RESPONSE=$(curl -s -X POST "${host}/api/v3/core/applications/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    --data-raw "{\"name\": \"${name}\", \"slug\": \"${slug}\", \"provider\": ${provider_pk}}")

  if echo "${APP_RESPONSE}" | jq -e '.pk' > /dev/null; then
    log_success "Application '${name}' created (PK: $(echo "${APP_RESPONSE}" | jq -r '.pk')). If it already existed, this might return an existing PK."
  else
    # Check if application already exists
    if echo "${APP_RESPONSE}" | grep -q "A application with this slug already exists"; then
      log_info "Application '${name}' already exists."
    else
      log_error "Failed to create application '${name}'. Response: ${APP_RESPONSE}"
    fi
  fi
}

# --- Main Script ---

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  log_info "Running in DRY-RUN mode. No changes will be made."
fi

# Load environment variables
if [ -f ./.env ]; then
  source ./.env
elif [ -f ../.env ]; then # For scripts in subdirectories
  source ../.env
elif [ -f ../../.env ]; then # For scripts in subdirectories
  source ../../.env
else
  log_error "Error: .env file not found. Please ensure it's in the script's directory or a parent."
fi

# Validate essential variables
if [ -z "${DOMAIN}" ] || [ -z "${AUTHENTIK_SECRET_KEY}" ] || \
   [ -z "${AUTHENTIK_BOOTSTRAP_EMAIL}" ] || [ -z "${AUTHENTIK_BOOTSTRAP_PASSWORD}" ] || \
   [ -z "${AUTHENTIK_DB_PASSWORD}" ] || [ -z "${AUTHENTIK_DOMAIN}" ]; then
  log_error "Missing essential environment variables. Please check your .env file."
fi

# Update AUTHENTIK_HOST with the actual domain
AUTHENTIK_HOST="https://${AUTHENTIK_DOMAIN}"

if [ "$DRY_RUN" == false ]; then
  wait_for_authentik "${AUTHENTIK_HOST}"
  AUTH_TOKEN=$(get_authentik_token "${AUTHENTIK_ADMIN_USERNAME}" "${AUTHENTIK_ADMIN_PASSWORD}" "${AUTHENTIK_HOST}")
  log_success "Successfully obtained Authentik API token."

  # Create groups
  for group_name in "${GROUPS[@]}"; do
    create_group "${group_name}" "${AUTH_TOKEN}" "${AUTHENTIK_HOST}"
  done
fi

echo ""
log_info "--- Authentik Provider and Application Setup ---"
echo ""

for service_config in "${SERVICES[@]}"; do
  IFS='|' read -r name redirect_uri scopes provider_type <<< "${service_config}"
  slug=$(echo "${name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/^-*//;s/-*$//')

  echo "--------------------------------------------------"
  log_info "Processing service: ${name}"
  log_info "  Redirect URI: ${redirect_uri}"
  log_info "  Scopes: ${scopes}"
  log_info "  Provider Type: ${provider_type}"

  if [ "$DRY_RUN" == true ]; then
    log_info "  (Dry-run) Would create provider and application for ${name}."
    log_info "  (Dry-run) Client ID and Secret would be generated."
    echo "--------------------------------------------------"
    continue
  fi

  PROVIDER_DETAILS=$(create_provider "${name}" "${redirect_uri}" "${scopes}" "${provider_type}" "${AUTH_TOKEN}" "${AUTHENTIK_HOST}")
  PROVIDER_PK=$(echo "${PROVIDER_DETAILS}" | jq -r '.pk')
  CLIENT_ID=$(echo "${PROVIDER_DETAILS}" | jq -r '.client_id')
  CLIENT_SECRET=$(echo "${PROVIDER_DETAILS}" | jq -r '.client_secret')

  if [ -z "${PROVIDER_PK}" ] || [ "${PROVIDER_PK}" == "null" ]; then
    log_error "Failed to get Provider PK for ${name}. Skipping application creation."
    continue
  fi

  create_application "${name}" "${slug}" "${PROVIDER_PK}" "${AUTH_TOKEN}" "${AUTHENTIK_HOST}"

  log_success "Created provider: ${name}"
  echo "      Client ID: ${CLIENT_ID}"
  echo "      Client Secret: ${CLIENT_SECRET}"
  echo "      Redirect URI: ${redirect_uri}"
  echo "--------------------------------------------------"
done

log_success "Authentik setup script finished."
