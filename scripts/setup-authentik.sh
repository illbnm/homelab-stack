#!/usr/bin/env bash
# Authentik SSO Setup - Create OIDC providers for all services
set -euo pipefail

AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.${DOMAIN}}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  echo "[DRY RUN MODE]"
fi

if [ -z "$AUTHENTIK_TOKEN" ]; then
  echo "Error: AUTHENTIK_TOKEN required. Create one in Authentik Admin > Directory > Tokens"
  exit 1
fi

API="$AUTHENTIK_URL/api/v3"
AUTH_HEADER="Authorization: Bearer $AUTHENTIK_TOKEN"

create_provider() {
  local name="$1"
  local redirect_uri="$2"
  local client_id client_secret

  client_id="$(openssl rand -hex 16)"
  client_secret="$(openssl rand -hex 32)"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create provider: $name"
    echo "  Client ID: $client_id"
    echo "  Redirect URI: $redirect_uri"
    return
  fi

  # Create OAuth2 Provider
  local response
  response=$(curl -sf -X POST "$API/providers/oauth2/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$name\",
      \"authorization_flow\": \"default-provider-authorization-implicit-consent\",
      \"client_type\": \"confidential\",
      \"client_id\": \"$client_id\",
      \"client_secret\": \"$client_secret\",
      \"redirect_uris\": \"$redirect_uri\"
    }" 2>/dev/null) || true

  if [ -n "$response" ]; then
    echo "[OK] Created provider: $name"
    echo "     Client ID: $client_id"
    echo "     Client Secret: $client_secret"
    echo "     Redirect URI: $redirect_uri"
  else
    echo "[SKIP] Provider '$name' may already exist"
  fi
  echo ""
}

echo "=== Authentik SSO Setup ==="
echo "URL: $AUTHENTIK_URL"
echo ""

create_provider "Grafana" "https://grafana.\${DOMAIN}/login/generic_oauth"
create_provider "Gitea" "https://gitea.\${DOMAIN}/user/oauth2/authentik/callback"
create_provider "Nextcloud" "https://cloud.\${DOMAIN}/apps/sociallogin/custom_oidc/authentik"
create_provider "Outline" "https://outline.\${DOMAIN}/auth/oidc.callback"
create_provider "Open WebUI" "https://ai.\${DOMAIN}/oauth/oidc/callback"
create_provider "Portainer" "https://portainer.\${DOMAIN}"

echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "1. Copy Client ID/Secret to each service's .env"
echo "2. Restart affected services"
echo "3. Test login at each service"
