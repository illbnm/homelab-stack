#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Configure Nextcloud Social Login (OIDC) against Authentik.
# Requires: docker, curl (optional), jq (optional)
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN:-}}"
NEXTCLOUD_OIDC_SLUG="${NEXTCLOUD_OIDC_SLUG:-nextcloud}"

NEXTCLOUD_OIDC_CLIENT_ID="${NEXTCLOUD_OIDC_CLIENT_ID:-}"
NEXTCLOUD_OIDC_CLIENT_SECRET="${NEXTCLOUD_OIDC_CLIENT_SECRET:-}"

if [ -z "$NEXTCLOUD_OIDC_CLIENT_ID" ] || [ -z "$NEXTCLOUD_OIDC_CLIENT_SECRET" ]; then
  echo "Missing NEXTCLOUD_OIDC_CLIENT_ID or NEXTCLOUD_OIDC_CLIENT_SECRET in .env" >&2
  exit 1
fi

if [ -z "$AUTHENTIK_DOMAIN" ]; then
  echo "Missing AUTHENTIK_DOMAIN (or DOMAIN) in .env" >&2
  exit 1
fi

provider_payload=$(cat <<EOF
[{
  "id": "authentik",
  "name": "Authentik",
  "title": "Authentik",
  "authorizeUrl": "https://${AUTHENTIK_DOMAIN}/application/o/authorize/",
  "tokenUrl": "https://${AUTHENTIK_DOMAIN}/application/o/token/",
  "profileUrl": "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/",
  "logoutUrl": "https://${AUTHENTIK_DOMAIN}/application/o/${NEXTCLOUD_OIDC_SLUG}/end-session/",
  "clientId": "${NEXTCLOUD_OIDC_CLIENT_ID}",
  "clientSecret": "${NEXTCLOUD_OIDC_CLIENT_SECRET}",
  "scope": "openid profile email",
  "isOpenIdConnect": true,
  "isDefault": true
}]
EOF
)

echo "Enabling Social Login app and applying OIDC configuration..."
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install sociallogin >/dev/null 2>&1 || true
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:enable sociallogin
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin custom_providers --value="$provider_payload"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set sociallogin allow_login --value="1"

echo "Nextcloud Social Login configured for Authentik."
