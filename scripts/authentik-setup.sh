#!/bin/bash
set -e

# Configuration
API_URL="https://${AUTHENTIK_DOMAIN}/api/v3"
TOKEN="${AUTHENTIK_API_TOKEN}"
DRY_RUN=false

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "--- DRY RUN MODE ---"
fi

if [[ -z "$TOKEN" ]]; then
    echo "Error: AUTHENTIK_API_TOKEN is not set."
    exit 1
fi

services=(
    "Grafana:https://grafana.${DOMAIN}/login/generic_oauth"
    "Gitea:https://gitea.${DOMAIN}/user/oauth2/authentik/callback"
    "Nextcloud:https://nextcloud.${DOMAIN}/index.php/apps/oidc_login/callback"
    "Outline:https://outline.${DOMAIN}/auth/oidc.callback"
    "OpenWebUI:https://ai.${DOMAIN}/auth/oidc/callback"
    "Portainer:https://portainer.${DOMAIN}/-/oauth/callback"
)

create_provider() {
    local name=$1
    local redirect_uri=$2
    
    echo "Processing provider: $name"
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create application $name and OIDC provider with URI $redirect_uri"
        return
    fi

    # 1. Create Application
    local app_resp=$(curl -s -X POST "$API_URL/applications/" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\", \"slug\": \"${name,,}\", \"title\": \"$name\"}")
    
    local app_id=$(echo "$app_resp" | jq -r '.pk')

    # 2. Create Provider
    local prov_resp=$(curl -s -X POST "$API_URL/providers/oauth2/" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name Provider\",
            \"slug\": \"${name,,}-provider\",
            \"authorization_flow\": \"default-authorization-flow\",
            \"client_type\": \"confidential\",
            \"redirect_uris\": [\"$redirect_uri\"],
            \"application\": $app_id
        }")

    local client_id=$(echo "$prov_resp" | jq -r '.client_id')
    local client_secret=$(echo "$prov_resp" | jq -r '.client_secret')

    echo "[OK] Created provider: $name"
    echo "     Client ID: $client_id"
    echo "     Client Secret: $client_secret"
    echo "     Redirect URI: $redirect_uri"
}

for service in "${services[@]}"; do
    IFS=":" read -r name uri <<< "$service"
    create_provider "$name" "$uri"
done
