#!/bin/bash
# Autoconfigures Authentik Providers and Applications via API

AUTHENTIK_URL="http://authentik-server:9000"
API_TOKEN=$1

if [ -z "$API_TOKEN" ]; then
  echo "Usage: ./authentik-setup.sh <api_token>"
  echo "Generate the token in the Authentik Admin interface under Directory -> Tokens."
  exit 1
fi

HEADERS=(
  "-H" "Authorization: Bearer $API_TOKEN"
  "-H" "Content-Type: application/json"
  "-H" "Accept: application/json"
)

# Providers and Apps setup
create_oidc_app() {
  local APP_NAME=$1
  local REDIRECT_URIS=$2
  
  echo "Setting up $APP_NAME..."
  
  # 1. Create Provider
  CLIENT_ID=$(openssl rand -hex 16)
  CLIENT_SECRET=$(openssl rand -hex 32)
  
  PROVIDER_PAYLOAD=$(cat <<EOF
{
  "name": "$APP_NAME Provider",
  "authorization_flow": "default-provider-authorization-explicit-consent",
  "client_id": "$CLIENT_ID",
  "client_secret": "$CLIENT_SECRET",
  "client_type": "confidential",
  "redirect_uris": "$REDIRECT_URIS",
  "property_mappings": [
    "ff2317b9-f027-4402-b2fa-fc449911e3ef",
    "b8b0e77d-ef73-4554-b371-d6a090e50fb3",
    "f2beafda-9418-4034-8c8f-287ccddde4ce",
    "b50bc568-cc24-4f40-aba1-285b0d0c48e8"
  ],
  "sub_mode": "hashed_user_id"
}
EOF
  )

  PROVIDER_ID=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/providers/oauth2/" "${HEADERS[@]}" -d "$PROVIDER_PAYLOAD" | jq -r '.pk')
  
  if [ "$PROVIDER_ID" == "null" ] || [ -z "$PROVIDER_ID" ]; then
    echo "[ERROR] Failed to create provider for $APP_NAME. (Check if it already exists)"
  else
    # 2. Create Application
    APP_PAYLOAD=$(cat <<EOF
{
  "name": "$APP_NAME",
  "slug": "$(echo $APP_NAME | tr '[:upper:]' '[:lower:]')",
  "provider": $PROVIDER_ID,
  "meta_launch_url": ""
}
EOF
    )
    curl -s -X POST "${AUTHENTIK_URL}/api/v3/core/applications/" "${HEADERS[@]}" -d "$APP_PAYLOAD" > /dev/null
    
    echo "[OK] Created provider: $APP_NAME"
    echo "     Client ID: $CLIENT_ID"
    echo "     Client Secret: $CLIENT_SECRET"
    echo "     Redirect URI: $REDIRECT_URIS"
    echo "---------------------------------------------------"
  fi
}

echo "Starting Authentik OIDC automated provisioning..."
create_oidc_app "Grafana" "https://grafana.example.com/login/generic_oauth"
create_oidc_app "Gitea" "https://git.example.com/user/oauth2/Authentik/callback"
create_oidc_app "Outline" "https://docs.example.com/auth/oidc.callback"
create_oidc_app "Nextcloud" "https://cloud.example.com/apps/user_oidc/login/oidc"
create_oidc_app "OpenWebUI" "https://ai.example.com/oauth/callback"
create_oidc_app "Portainer" "https://portainer.example.com/auth/oauth/callback"

echo "Provisioning complete. Insert the above credentials into their respective .env files."
