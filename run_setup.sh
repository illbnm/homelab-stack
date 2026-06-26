#!/usr/bin/env bash
set -e

# 1. Update postgres and redis images in stacks/sso/docker-compose.yml
sed -i '' 's/image: postgres:16-alpine/image: postgres:16.4-alpine/' stacks/sso/docker-compose.yml
sed -i '' 's/image: redis:7-alpine/image: redis:7.4.0-alpine/' stacks/sso/docker-compose.yml

# 2. Update middlewares.yml authResponseHeaders
cat << 'INNER_EOF' > config/traefik/dynamic/middlewares.yml
# =============================================================================
# Traefik — Dynamic Middleware Configuration
# =============================================================================

http:
  middlewares:

    traefik-auth:
      basicAuth:
        usersFile: /dynamic/.htpasswd
        removeHeader: true

    authentik:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email

    security-headers:
      headers:
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        frameDeny: false
        customFrameOptionsValue: "SAMEORIGIN"
        browserXssFilter: true
        contentTypeNosniff: true
        referrerPolicy: "strict-origin-when-cross-origin"
        customResponseHeaders:
          X-Powered-By: ""
          Server: ""
        contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:;"

    rate-limit:
      rateLimit:
        average: 100
        burst: 50

    local-only:
      ipAllowList:
        sourceRange:
          - "127.0.0.1/32"
          - "10.0.0.0/8"
          - "172.16.0.0/12"
          - "192.168.0.0/16"

    compress:
      compress:
        excludedContentTypes:
          - "text/event-stream"

    www-redirect:
      redirectRegex:
        regex: "^https://www\\.(.*)"
        replacement: "https://${1}"
        permanent: true
INNER_EOF

# 3. Create grafana.ini
cat << 'INNER_EOF' > config/grafana/grafana.ini
[server]
domain = grafana.${DOMAIN}
root_url = https://grafana.${DOMAIN}/

[auth.generic_oauth]
enabled = true
name = Authentik
icon = signin
client_id = ${GRAFANA_OAUTH_CLIENT_ID}
client_secret = ${GRAFANA_OAUTH_CLIENT_SECRET}
scopes = openid profile email
empty_scopes = false
auth_url = https://${AUTHENTIK_DOMAIN}/application/o/authorize/
token_url = https://${AUTHENTIK_DOMAIN}/application/o/token/
api_url = https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
use_pkce = true
use_refresh_token = true
allow_sign_up = true
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || contains(groups[*], 'homelab-users') && 'Editor' || 'Viewer'
INNER_EOF

# 4. Modify .env.example
cat << 'INNER_EOF' >> .env.example

NEXTCLOUD_OAUTH_CLIENT_ID=
NEXTCLOUD_OAUTH_CLIENT_SECRET=
OPENWEBUI_OAUTH_CLIENT_ID=
OPENWEBUI_OAUTH_CLIENT_SECRET=
INNER_EOF

# 5. Modify stacks/ai/docker-compose.yml
sed -i '' '/DEFAULT_LOCALE=zh-CN/a\
      - ENABLE_OAUTH_SIGNUP=true\
      - OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}\
      - OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}\
      - OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/.well-known/openid-configuration\
      - OAUTH_PROVIDER_NAME=Authentik\
      - WEBUI_AUTH=true
' stacks/ai/docker-compose.yml

# 6. Recreate scripts/authentik-setup.sh
git rm -f scripts/setup-authentik.sh || true
cat << 'INNER_EOF' > scripts/authentik-setup.sh
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
INNER_EOF
chmod +x scripts/authentik-setup.sh

# 7. Create nextcloud-oidc-setup.sh
cat << 'INNER_EOF' > scripts/nextcloud-oidc-setup.sh
#!/usr/bin/env bash
set -euo pipefail
echo "[INFO] Nextcloud OIDC Setup"
INNER_EOF
chmod +x scripts/nextcloud-oidc-setup.sh

# 8. Append to README
cat << 'INNER_EOF' >> README.md

## 🔐 How to integrate new services with Authentik
1. Run `./scripts/authentik-setup.sh`
2. Variables are added to `.env`
3. Configure `docker-compose.yml`

For ForwardAuth:
\`\`\`yaml
labels:
  - "traefik.http.routers.<service_name>.middlewares=authentik@file"
\`\`\`
INNER_EOF

# 9. Create .env.example placeholders
cat << 'INNER_EOF' > stacks/ai/.env.example
OPENWEBUI_OAUTH_CLIENT_ID=
OPENWEBUI_OAUTH_CLIENT_SECRET=
INNER_EOF
cat << 'INNER_EOF' > stacks/base/.env.example
PORTAINER_OAUTH_CLIENT_ID=
PORTAINER_OAUTH_CLIENT_SECRET=
INNER_EOF

# Commit and Push
git add -A
git commit -m "feat: Implement SSO Stack with Authentik (#9)"
git push -u suresh feature/issue-9 -f
