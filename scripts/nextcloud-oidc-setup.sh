#!/usr/bin/env bash
# Configure Nextcloud "Social Login" app with a custom OIDC provider (Authentik).
# Idempotent: `occ config:app:set` overwrites existing keys.
set -euo pipefail
: "${NEXTCLOUD_CONTAINER:=nextcloud}"
: "${NEXTCLOUD_CLIENT_ID:?}"; : "${NEXTCLOUD_CLIENT_SECRET:?}"
: "${AUTHENTIK_DOMAIN:?}"; : "${BASE_DOMAIN:?}"

occ() { docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"; }

occ app:install sociallogin || true
occ app:enable sociallogin

json=$(jq -n --arg id "$NEXTCLOUD_CLIENT_ID" --arg secret "$NEXTCLOUD_CLIENT_SECRET" \
  --arg base "https://${AUTHENTIK_DOMAIN}/application/o/nextcloud" '{
    custom_oidc: [{
      name: "authentik", title: "Authentik SSO",
      authorize_url: "\($base)/authorize/",
      token_url:     "\($base)/token/",
      user_info_url: "\($base)/userinfo/",
      logout_url:    "\($base)/end-session/",
      client_id: $id, client_secret: $secret,
      scope: "openid profile email",
      groups_claim: "groups",
      style: "", default_group: ""
    }]
  }')

occ config:app:set sociallogin custom_providers --value="$json"
occ config:app:set sociallogin auto_create_groups --value="1"
occ config:app:set sociallogin restrict_users_to_known_groups --value="0"
echo "[OK] Nextcloud OIDC (authentik) configured."
