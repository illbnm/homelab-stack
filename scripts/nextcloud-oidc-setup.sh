#!/usr/bin/env bash
# Configure Nextcloud Social Login for the Authentik OIDC provider.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

load_env_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/stacks/sso/.env"
load_env_file "$ROOT_DIR/stacks/storage/.env"

DOMAIN="${DOMAIN:-}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-${DOMAIN:+auth.${DOMAIN}}}"
CLIENT_ID="${NEXTCLOUD_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${NEXTCLOUD_OAUTH_CLIENT_SECRET:-}"
CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"

[[ -n "$DOMAIN" ]] || { echo "DOMAIN is required" >&2; exit 1; }
[[ -n "$AUTHENTIK_DOMAIN" ]] || { echo "AUTHENTIK_DOMAIN is required" >&2; exit 1; }
[[ -n "$CLIENT_ID" ]] || { echo "NEXTCLOUD_OAUTH_CLIENT_ID is required" >&2; exit 1; }
[[ -n "$CLIENT_SECRET" ]] || { echo "NEXTCLOUD_OAUTH_CLIENT_SECRET is required" >&2; exit 1; }

docker inspect "$CONTAINER" >/dev/null 2>&1 || {
  echo "Container '$CONTAINER' is not running" >&2
  exit 1
}

occ() {
  docker exec -u www-data "$CONTAINER" php occ "$@"
}

if ! occ app:list | grep -q "sociallogin"; then
  occ app:install sociallogin
fi
occ app:enable sociallogin >/dev/null

providers_json="$(jq -cn \
  --arg client_id "$CLIENT_ID" \
  --arg client_secret "$CLIENT_SECRET" \
  --arg auth_domain "$AUTHENTIK_DOMAIN" \
  '{
    custom_oidc: [
      {
        name: "authentik",
        title: "Authentik",
        authorizeUrl: ("https://" + $auth_domain + "/application/o/authorize/"),
        tokenUrl: ("https://" + $auth_domain + "/application/o/token/"),
        userInfoUrl: ("https://" + $auth_domain + "/application/o/userinfo/"),
        logoutUrl: ("https://" + $auth_domain + "/application/o/nextcloud/end-session/"),
        clientId: $client_id,
        clientSecret: $client_secret,
        scope: "openid profile email",
        groupsClaim: "groups",
        displayNameClaim: "preferred_username",
        style: "openid",
        defaultGroup: ""
      }
    ]
  }')"

occ config:app:set sociallogin prevent_create_email_exists --value=1
occ config:app:set sociallogin update_profile_on_login --value=1
occ config:app:set sociallogin custom_providers --value="$providers_json"

echo "Nextcloud Social Login configured for Authentik"
