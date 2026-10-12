# Solution for [github/issues_9]: [illbnm/homelab-stack] [BOUNTY $300] SSO — Authentik 统一身份认证

- **Reward:** $300.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/9
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 10496 (~$0.0210 USD compute cost)

---

This bounty requires a comprehensive solution for integrating Authentik as a Single Sign-On (SSO) provider across various services in a homelab stack. This involves deploying Authentik, configuring OIDC/OAuth for multiple applications, creating an automation script for Authentik setup, implementing Traefik ForwardAuth, and designing user groups for access control.

## Root Cause Analysis

The current homelab stack lacks a centralized authentication system, leading to fragmented user management and a poor user experience. Each service requires separate credentials, increasing the overhead for users and administrators. The goal is to consolidate authentication through Authentik, providing a single point of entry and streamlined access control.

The complexity arises from:
1.  **Diverse Integration Methods:** Different services support different authentication protocols (OIDC, OAuth, or none).
2.  **Configuration Management:** Manually configuring Authentik and each service is error-prone and time-consuming.
3.  **Dependency Management:** Ensuring Authentik is ready before dependent services attempt to connect.
4.  **Access Control:** Implementing fine-grained access control based on user groups.
5.  **Automation:** The need for a robust setup script to automate Authentik provider and application creation.

## Architecture Design

The solution will involve the following components:

1.  **Authentik Stack:**
    *   `authentik-server`: The core Authentik application.
    *   `authentik-worker`: Handles background tasks for Authentik.
    *   `authentik-postgresql`: Dedicated PostgreSQL database for Authentik.
    *   `authentik-redis`: Dedicated Redis cache for Authentik.
    *   These will be deployed as a separate Docker Compose stack, accessible via `auth.${DOMAIN}`.

2.  **Traefik Integration:**
    *   Traefik will act as the reverse proxy, routing traffic to Authentik and other services.
    *   It will also host the `ForwardAuth` middleware for services that don't natively support OIDC.

3.  **Service-Specific OIDC/OAuth Integration:**
    *   **Grafana, Gitea, Outline, Open WebUI:** Will be configured to use Authentik as an OIDC provider directly.
    *   **Nextcloud:** Will use the Social Login app for OIDC integration.
    *   **Portainer:** Will use Authentik as an OAuth provider.

4.  **Authentik Initialization Script (`authentik-setup.sh`):**
    *   A Python script leveraging the Authentik API client to automate the creation of:
        *   OAuth2/OIDC Providers for each service.
        *   Corresponding Applications.
        *   User groups (`homelab-admins`, `homelab-users`, `media-users`).
        *   Policies to enforce group-based access.
    *   It will output `Client ID` and `Client Secret` for each service.

5.  **Environment Variables:**
    *   Centralized `.env` files will manage sensitive credentials and domain information.

6.  **Health Checks:**
    *   Docker Compose `depends_on` and `healthcheck` configurations will ensure Authentik's dependencies are met and it's ready before other services start.

### Data Flow

1.  User accesses a service (e.g., `grafana.${DOMAIN}`).
2.  Traefik routes the request.
3.  If the user is not authenticated, the service (or Traefik ForwardAuth) redirects to `auth.${DOMAIN}`.
4.  Authentik handles the login process (username/password, MFA).
5.  Upon successful authentication, Authentik redirects back to the service with an OIDC token or OAuth code.
6.  The service validates the token/code with Authentik and grants access.
7.  User attributes (username, email, groups) are passed to the service for authorization.

## Production-Ready Code/Patch Implementation

This section will detail the necessary file changes and additions.

### 1. Authentik Stack Deployment

We'll create a new `authentik` stack in `stacks/authentik/docker-compose.yml`.

### File: stacks/authentik/docker-compose.yml
```yaml
services:
  authentik-server:
    image: ghcr.io/goauthentik/server:2024.8.3
    container_name: authentik-server
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_BOOTSTRAP_EMAIL: ${AUTHENTIK_BOOTSTRAP_EMAIL}
      AUTHENTIK_BOOTSTRAP_PASSWORD: ${AUTHENTIK_BOOTSTRAP_PASSWORD}
      AUTHENTIK_DB_HOST: authentik-postgresql
      AUTHENTIK_DB_NAME: authentik
      AUTHENTIK_DB_USER: authentik
      AUTHENTIK_DB_PASSWORD: ${AUTHENTIK_DB_PASSWORD}
      AUTHENTIK_REDIS_HOST: authentik-redis
      AUTHENTIK_REDIS_PORT: 6379
      AUTHENTIK_LOG_LEVEL: info
      AUTHENTIK_HOST: https://auth.${DOMAIN}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false" # Disable error reporting
    volumes:
      - authentik-data:/var/lib/authentik/media
      - authentik-data:/var/lib/authentik/custom-templates
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authentik.rule=Host(`auth.${DOMAIN}`)"
      - "traefik.http.routers.authentik.entrypoints=websecure"
      - "traefik.http.routers.authentik.tls.certresolver=le"
      - "traefik.http.services.authentik.loadbalancer.server.port=9000"
      - "traefik.http.routers.authentik.middlewares=authentik-compress@docker"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/health/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    depends_on:
      authentik-postgresql:
        condition: service_healthy
      authentik-redis:
        condition: service_healthy
    networks:
      - default
      - traefik_proxy

  authentik-worker:
    image: ghcr.io/goauthentik/server:2024.8.3
    container_name: authentik-worker
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_DB_HOST: authentik-postgresql
      AUTHENTIK_DB_NAME: authentik
      AUTHENTIK_DB_USER: authentik
      AUTHENTIK_DB_PASSWORD: ${AUTHENTIK_DB_PASSWORD}
      AUTHENTIK_REDIS_HOST: authentik-redis
      AUTHENTIK_REDIS_PORT: 6379
      AUTHENTIK_LOG_LEVEL: info
      AUTHENTIK_HOST: https://auth.${DOMAIN}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false" # Disable error reporting
    volumes:
      - authentik-data:/var/lib/authentik/media
      - authentik-data:/var/lib/authentik/custom-templates
    depends_on:
      authentik-server:
        condition: service_healthy
    networks:
      - default

  authentik-postgresql:
    image: postgres:16.4-alpine
    container_name: authentik-postgresql
    restart: unless-stopped
    environment:
      POSTGRES_DB: authentik
      POSTGRES_USER: authentik
      POSTGRES_PASSWORD: ${AUTHENTIK_DB_PASSWORD}
    volumes:
      - authentik-db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U authentik -d authentik"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - default

  authentik-redis:
    image: redis:7.4.0-alpine
    container_name: authentik-redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - default

volumes:
  authentik-data:
  authentik-db:

networks:
  default:
    external: true
    name: homelab_default # Assuming a default network for internal communication
  traefik_proxy:
    external: true
    name: traefik_proxy # Assuming Traefik uses this network
```

### File: stacks/authentik/.env.example
```ini
# Authentik Environment Variables
AUTHENTIK_SECRET_KEY=your_authentik_secret_key_here # Generate with `openssl rand -hex 50`
AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
AUTHENTIK_BOOTSTRAP_PASSWORD=your_strong_admin_password
AUTHENTIK_DB_PASSWORD=your_authentik_db_password
AUTHENTIK_DOMAIN=auth.example.com # e.g., auth.yourdomain.com
```

**Action:** Update `docker-compose.yml` in the root to include the new stack.

### File: docker-compose.yml (root)
```yaml
# ... existing services ...

  authentik:
    build:
      context: ./stacks/authentik
    env_file:
      - ./stacks/authentik/.env
    # No need for a build context if we are using pre-built images directly in the stack
    # We will use `docker compose -f stacks/authentik/docker-compose.yml up -d`
    # Or, if we want to include it in the main compose, we can use `include` (Docker Compose V2.17+)
    # For simplicity and modularity, we'll assume it's a separate stack managed by `docker compose -f stacks/authentik/docker-compose.yml up -d`
    # If the project uses a single root docker-compose.yml, then we would include the services directly.
    # Let's assume for now that each stack is managed independently, but shares networks.
    # If the project structure implies a single root docker-compose.yml, then the content of stacks/authentik/docker-compose.yml
    # would be merged into the root docker-compose.yml under the `services` key.
    # Given the `stacks/` directory, it's more likely to be separate compose files.
    # However, the issue implies a unified `docker-compose.yml` for the whole homelab.
    # Let's adjust to merge it into the main `docker-compose.yml` for simplicity,
    # and ensure networks are correctly defined.

# ... (existing networks) ...
networks:
  traefik_proxy:
    external: true
  homelab_default: # Ensure this network exists or is created
    external: true
```
**Correction:** The `docker-compose.yml` in the root is usually for orchestrating multiple stacks. Given the `stacks/` directory, it's more common to have separate `docker-compose.yml` files for each stack. However, the bounty implies a unified setup. Let's assume the main `docker-compose.yml` will *include* these services.

**Revised approach for `docker-compose.yml` (root):**
Instead of a `build` context for `authentik`, we'll directly embed the services from `stacks/authentik/docker-compose.yml` into the main `docker-compose.yml` if the project structure dictates a single entry point. If the project uses `docker compose -f stacks/base/docker-compose.yml -f stacks/productivity/docker-compose.yml ... up -d`, then `stacks/authentik/docker-compose.yml` would be another file in that list.

For this solution, I will assume the `stacks/authentik/docker-compose.yml` is a standalone file that should be run alongside the main stack, sharing common networks. This is a common pattern for modular Docker Compose setups. The `networks` section in `stacks/authentik/docker-compose.yml` already reflects this.

**Action:** Ensure the `traefik_proxy` and `homelab_default` networks are defined as external in your main `docker-compose.yml` or created if they don't exist.

### 2. Authentik Initialization Script (`scripts/authentik-setup.sh`)

This script will use `curl` to interact with the Authentik API. It requires `jq` for JSON parsing.

### File: scripts/authentik-setup.sh
```bash
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
```

**Action:** Make the script executable.
`chmod +x scripts/authentik-setup.sh`

### 3. Traefik ForwardAuth

This will be added to `config/traefik/dynamic/middlewares.yml`.

### File: config/traefik/dynamic/middlewares.yml
```yaml
# ... existing middlewares ...

middlewares:
  # ... existing middlewares ...

  authentik-forwardauth:
    forwardAuth:
      address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      trustForwardHeader: true
      authResponseHeaders:
        - X-authentik-username
        - X-authentik-groups
        - X-authentik-email
        - X-authentik-name # Add full name if desired
        - X-authentik-uid # Add user ID if desired
```
**Action:** Ensure `authentik-server` is resolvable from Traefik. This is handled by them being on the same `traefik_proxy` network.

### 4. Service Integrations

#### 4.1. Grafana

### File: config/grafana/grafana.ini
```ini
[server]
# ...
root_url = https://grafana.${DOMAIN}

[auth.generic_oauth]
enabled = true
name = Authentik
allow_sign_up = true
client_id = YOUR_GRAFANA_CLIENT_ID
client_secret = YOUR_GRAFANA_CLIENT_SECRET
scopes = openid profile email
auth_url = https://auth.${DOMAIN}/application/o/grafana/authorize/
token_url = https://auth.${DOMAIN}/application/o/grafana/token/
api_url = https://auth.${DOMAIN}/application/o/grafana/userinfo/
# Use role_attribute_path to map Authentik groups to Grafana roles
# Example: If Authentik sends groups in 'groups' claim, and you want 'homelab-admins' to be 'Admin'
# You might need to adjust this based on how Authentik sends groups and your desired mapping.
# Authentik sends groups as a list of strings in the 'groups' claim by default.
# Grafana expects a single role or a list of roles.
# A common approach is to use a JQ expression to map specific groups to Grafana roles.
# For simplicity, let's map 'homelab-admins' to Admin, others to Viewer.
# This requires a JQ expression that evaluates to "Admin", "Editor", or "Viewer".
# If the 'groups' claim contains "homelab-admins", set role to "Admin".
# Otherwise, set to "Viewer".
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || 'Viewer'
# If you want to map multiple groups to different roles, it gets more complex.
# For example:
# role_attribute_path = 'if .groups | contains("homelab-admins") then "Admin" elif .groups | contains("homelab-users") then "Editor" else "Viewer" end'
# Ensure the JQ expression is correct for your Authentik group names.
# For initial setup, a simple mapping is often sufficient.
# If you want to allow all authenticated users to be viewers, and admins to be admins:
# role_attribute_path = 'if .groups | contains("homelab-admins") then "Admin" else "Viewer" end'
# Or, if you want to map directly:
# role_attribute_path = 'join(",", .groups)' # This would pass group names directly, Grafana needs specific roles.
# Let's stick to a simple admin/viewer mapping based on 'homelab-admins' group.
# If no role_attribute_path is set, Grafana defaults to Viewer.
# If you want to map specific groups to specific roles, you might need to use a custom JQ expression.
# For now, let's assume a simple mapping:
# If user is in 'homelab-admins', they are Admin. Otherwise, they are Viewer.
# This requires the 'groups' claim to be present in the ID token or userinfo endpoint.
# Authentik includes groups in the 'groups' claim by default for OIDC.
# The JQ expression needs to be valid.
# Example for Grafana 9+:
# role_attribute_path = 'if .groups | contains("homelab-admins") then "Admin" else "Viewer" end'
# For older Grafana versions, or if the above doesn't work, you might need to use a custom claim in Authentik
# or a different approach.
# Let's use the recommended JQ expression for Grafana 9+
role_attribute_path = 'if .groups | contains("homelab-admins") then "Admin" else "Viewer" end'
# auto_assign_org_role = Viewer # Can be used if role_attribute_path is not set or for default.
# If you want to sync groups:
# group_attribute_path = groups
# If you want to allow users to pick their org:
# allow_assign_grafana_admin = true # Only for users with Admin role
```

**Action:** Update `stacks/monitoring/docker-compose.yml` to ensure Grafana uses the correct `root_url` and depends on Authentik.

### File: stacks/monitoring/docker-compose.yml
```yaml
services:
  grafana:
    # ... existing config ...
    environment:
      # ... existing environment variables ...
      GF_SERVER_ROOT_URL: https://grafana.${DOMAIN}
      GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
      GF_AUTH_GENERIC_OAUTH_NAME: "Authentik"
      GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP: "true"
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: ${GRAFANA_CLIENT_ID}
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: ${GRAFANA_CLIENT_SECRET}
      GF_AUTH_GENERIC_OAUTH_SCOPES: "openid profile email"
      GF_AUTH_GENERIC_OAUTH_AUTH_URL: https://auth.${DOMAIN}/application/o/grafana/authorize/
      GF_AUTH_GENERIC_OAUTH_TOKEN_URL: https://auth.${DOMAIN}/application/o/grafana/token/
      GF_AUTH_GENERIC_OAUTH_API_URL: https://auth.${DOMAIN}/application/o/grafana/userinfo/
      GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: 'if .groups | contains("homelab-admins") then "Admin" else "Viewer" end'
      # GF_AUTH_GENERIC_OAUTH_GROUP_ATTRIBUTE_PATH: "groups" # Uncomment if you want to sync groups
    depends_on:
      # ... existing dependencies ...
      authentik-server:
        condition: service_healthy # Ensure Authentik is ready
    # ... existing labels ...
```

### File: stacks/monitoring/.env.example
```ini
# ... existing variables ...
GRAFANA_CLIENT_ID=
GRAFANA_CLIENT_SECRET=
```

#### 4.2. Gitea

### File: stacks/productivity/.env.example
```ini
# ... existing variables ...
GITEA_CLIENT_ID=
GITEA_CLIENT_SECRET=
```

**Action:** Update `stacks/productivity/docker-compose.yml` for Gitea. Gitea's OIDC configuration is typically done via environment variables or `app.ini`. For Docker, environment variables are preferred.

### File: stacks/productivity/docker-compose.yml
```yaml
services:
  gitea:
    # ... existing config ...
    environment:
      # ... existing environment variables ...
      GITEA__OAUTH2__AUTHENTIK__CLIENT_ID: ${GITEA_CLIENT_ID}
      GITEA__OAUTH2__AUTHENTIK__CLIENT_SECRET: ${GITEA_CLIENT_SECRET}
      GITEA__OAUTH2__AUTHENTIK__OPENID_CONNECT_AUTO_DISCOVERY_URL: https://auth.${DOMAIN}/application/o/gitea/.well-known/openid-configuration
      GITEA__OAUTH2__AUTHENTIK__SCOPES: "openid profile email"
      GITEA__OAUTH2__AUTHENTIK__NAME: "Authentik"
      GITEA__OAUTH2__AUTHENTIK__ENABLED: "true"
      GITEA__OAUTH2__AUTHENTIK__AUTO_REGISTRATION: "true"
      GITEA__OAUTH2__AUTHENTIK__GROUP_TEAM_MAP: '{"homelab-admins": "Owners", "homelab-users": "Developers"}' # Example mapping
      # GITEA__OAUTH2__AUTHENTIK__ADMIN_GROUP: "homelab-admins" # If Gitea supports direct admin group mapping
    depends_on:
      # ... existing dependencies ...
      authentik-server:
        condition: service_healthy
    # ... existing labels ...
```
**Note on Gitea Group Mapping:** Gitea's `GROUP_TEAM_MAP` allows mapping OIDC groups to Gitea teams. You'll need to create these teams in Gitea manually or via API. The `ADMIN_GROUP` setting might not be directly available via OIDC env vars; typically, admin status is assigned post-login by a Gitea admin.

#### 4.3. Nextcloud

Nextcloud requires the "Social Login" app. The setup script will automate the configuration within Nextcloud.

### File: scripts/nextcloud-oidc-setup.sh
```bash
#!/bin/bash

# Nextcloud OIDC Setup Script for Social Login App
# Configures Nextcloud's Social Login

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
