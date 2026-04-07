#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Authentik SSO Setup Script
# Creates OIDC providers for all services + User groups + ForwardAuth config
# Requires: curl, jq
# Usage: ./scripts/setup-authentik.sh [--dry-run]
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

# Check for dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log_warn "DRY RUN MODE - No changes will be made"
fi

AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
API_URL="$AUTHENTIK_URL/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set in .env"
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
  local scopes="${5:-openid profile email}"

  log_step "Creating OIDC provider: $name"

  local flow_pk signing_key
  flow_pk=$(get_default_flow authorize)
  signing_key=$(get_signing_key)
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

  local payload
  payload=$(jq -n \
    --arg name "${name} Provider" \
    --arg flow "$flow_pk" \
    --arg uri "$redirect_uri" \
    --arg key "$signing_key" \
    --arg scopes "$scopes" \
    '{
      name: $name,
      authorization_flow: $flow,
      client_type: "confidential",
      redirect_uris: [$uri],
      sub_mode: "hashed_user_id",
      include_claims_in_id_token: true,
      signing_key: $key,
      scopes: ($scopes | split(" "))
    }')

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would create OIDC provider: $name"
    log_info "  Redirect URI: $redirect_uri"
    log_info "  Scopes: $scopes"
    return 0
  fi

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
  log_info "  Client ID:   $client_id"

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

create_user_group() {
  local name="$1"
  local description="$2"
  local users="${3:-}"

  log_step "Creating user group: $name"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would create user group: $name"
    log_info "  Description: $description"
    if [[ -n "$users" ]]; then
      log_info "  Initial users: $users"
    fi
    return 0
  fi

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    '{
      name: $name,
      description: $description
    }')

  local group_pk
  group_pk=$(curl -sf -X POST "$API_URL/core/groups/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" | jq -r '.pk')

  log_info "  Group created: $name (PK: $group_pk)"

  if [[ -n "$users" ]]; then
    local user_arr
    user_arr=$(jq -n '[$users | split(" ")]' --arg users "$users")
    
    for user in $users; do
      local user_payload
      user_payload=$(jq -n --arg user "$user" '{user: {username: $user}}')
      
      curl -sf -X POST "$API_URL/core/groups/${group_pk}/users/" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "$user_payload" > /dev/null
    done
    log_info "  Added users to group: $users"
  fi
}

configure_forward_auth() {
  log_step "Configuring Traefik ForwardAuth middleware"

  local middleware_dir="$ROOT_DIR/config/traefik/dynamic"
  local middleware_file="$middleware_dir/middlewares.yml"

  if [[ ! -d "$middleware_dir" ]]; then
    mkdir -p "$middleware_dir"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would create ForwardAuth middleware config"
    return 0
  fi

  cat > "$middleware_file" << 'EOF'
middlewares:
  authentik:
    forwardAuth:
      address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      trustForwardHeader: true
      authResponseHeaders:
        - X-authentik-username
        - X-authentik-groups
        - X-authentik-email
        - X-authentik-name
        - X-authentik-uid
  security-headers:
    headers:
      customResponseHeaders:
      X-Content-Type-Options: "nosniff"
      X-Frame-Options: "DENY"
      X-XSS-Protection: "1; mode=block"
      Referrer-Policy: "strict-origin-when-cross-origin"
      Permissions-Policy: "geolocation=(), camera=(), microphone=()"
EOF

  log_info "  ForwardAuth middleware configured"
}

# Generate initial environment variables
generate_secrets() {
  log_step "Generating required secrets"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would generate secrets"
    return 0
  fi

  # Generate secrets if not already present
  if [[ -z "${AUTHENTIK_SECRET_KEY:-}" ]]; then
    export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
    sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" "$ROOT_DIR/.env"
    log_info "  Generated AUTHENTIK_SECRET_KEY"
  fi

  if [[ -z "${AUTHENTIK_POSTGRES_PASSWORD:-}" ]]; then
    export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
    sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" "$ROOT_DIR/.env"
    log_info "  Generated AUTHENTIK_POSTGRES_PASSWORD"
  fi

  if [[ -z "${AUTHENTIK_REDIS_PASSWORD:-}" ]]; then
    export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
    sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" "$ROOT_DIR/.env"
    log_info "  Generated AUTHENTIK_REDIS_PASSWORD"
  fi
}

# ------------------------------------------------------------------
# Wait for Authentik to be ready
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Generate secrets if needed
# ------------------------------------------------------------------
generate_secrets

# ------------------------------------------------------------------
# Create OIDC providers
# ------------------------------------------------------------------
log_step "Creating OIDC providers for all services"

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
  "Outline" \
  "https://docs.${DOMAIN}/auth/oidc.callback" \
  "OUTLINE_OAUTH_CLIENT_ID" \
  "OUTLINE_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Portainer" \
  "https://portainer.${DOMAIN}/" \
  "PORTAINER_OAUTH_CLIENT_ID" \
  "PORTAINER_OAUTH_CLIENT_SECRET"

# New providers for bounty requirements
create_oidc_provider \
  "Open WebUI" \
  "https://ai.${DOMAIN}/oauth/callback" \
  "OPEN_WEBUI_OAUTH_CLIENT_ID" \
  "OPEN_WEBUI_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Nextcloud" \
  "https://nextcloud.${DOMAIN}/apps/sociallogin/callback" \
  "NEXTCLOUD_OAUTH_CLIENT_ID" \
  "NEXTCLOUD_OAUTH_CLIENT_SECRET"

create_oidc_provider \
  "Bookstack" \
  "https://wiki.${DOMAIN}/login/oauth/azure/callback" \
  "BOOKSTACK_OIDC_CLIENT_ID" \
  "BOOKSTACK_OIDC_CLIENT_SECRET"

# ------------------------------------------------------------------
# Create user groups
# ------------------------------------------------------------------
log_step "Creating user groups"

create_user_group "homelab-admins" "Full access to all services"
create_user_group "homelab-users" "Access to regular services"
create_user_group "media-users" "Access to media services only (Jellyfin, Jellyseerr)"

# ------------------------------------------------------------------
# Configure ForwardAuth middleware
# ------------------------------------------------------------------
configure_forward_auth

# ------------------------------------------------------------------
# Update service configurations with OIDC
# ------------------------------------------------------------------
log_step "Updating service configurations"

if [[ "$DRY_RUN" == "false" ]]; then
  # Update Open WebUI configuration
  if [[ -f "$ROOT_DIR/stacks/ai/docker-compose.yml" ]]; then
    sed -i '/^      - WEBUI_SECRET_KEY=/a\\      - ENABLE_OIDC=true\\      - OIDC_PROVIDER_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/open-webui/\\      - OIDC_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID}\\      - OIDC_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}\\      - OIDC_REDIRECT_URL=https://ai.'"${DOMAIN}"'/oauth/callback' "$ROOT_DIR/stacks/ai/docker-compose.yml"
    log_info "  Updated Open WebUI configuration"
  fi

  # Update Nextcloud configuration for OIDC social login
  if [[ -f "$ROOT_DIR/stacks/storage/docker-compose.yml" ]]; then
    # Add OIDC environment variables to Nextcloud
    sed -i '/^      - REDIS_HOST=homelab-redis/a\\      - SOCIAL_LOGIN_ENABLED=true\\      - SOCIAL_LOGIN_AUTO_CREATE_USERS=false\\      - SOCIAL_LOGIN_NAME=authentik\\      - SOCIAL_LOGIN_CLIENT_ID=${NEXTCLOUD_OAUTH_CLIENT_ID}\\      - SOCIAL_LOGIN_CLIENT_SECRET=${NEXTCLOUD_OAUTH_CLIENT_SECRET}\\      - SOCIAL_LOGIN_METADATA_PROVIDER_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/nextcloud/.well-known/openid-configuration' "$ROOT_DIR/stacks/storage/docker-compose.yml"
    log_info "  Updated Nextcloud configuration"
  fi

  # Update Portainer configuration for OIDC
  if [[ -f "$ROOT_DIR/stacks/base/docker-compose.yml" ]]; then
    sed -i '/^      - WATCHTOWER_LABEL_ENABLE=true/a\\      - PORTAINER_OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}\\      - PORTAINER_OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}\\      - PORTAINER_OAUTH_AUTH_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/portainer/authorize\\      - PORTAINER_OAUTH_TOKEN_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/portainer/token\\      - PORTAINER_OAUTH_USERINFO_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/portainer/userinfo\\      - PORTAINER_OAUTH_API_URL=https://'"${AUTHENTIK_DOMAIN}"'/application/o/portainer/userinfo' "$ROOT_DIR/stacks/base/docker-compose.yml"
    log_info "  Updated Portainer configuration"
  fi
fi

log_step "Setup completed successfully!"
log_info "All OIDC providers created and user groups configured."
log_info "Services are ready for Authentik integration."
log_info "Remember to update service configurations with proper Traefik middlewares."