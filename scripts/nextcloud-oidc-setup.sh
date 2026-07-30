#!/usr/bin/env bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════
# Nextcloud OIDC Setup Script
# Configures Nextcloud to use Authentik as OIDC provider
# ════════════════════════════════════════════════════════════════

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
DOMAIN="${DOMAIN:-example.com}"
OIDC_CLIENT_ID="${NEXTCLOUD_OIDC_CLIENT_ID:-}"
OIDC_CLIENT_SECRET="${NEXTCLOUD_OIDC_CLIENT_SECRET:-}"

if [[ -z "$OIDC_CLIENT_ID" ]] || [[ -z "$OIDC_CLIENT_SECRET" ]]; then
  echo "ERROR: NEXTCLOUD_OIDC_CLIENT_ID and NEXTCLOUD_OIDC_CLIENT_SECRET must be set."
  echo "Run scripts/authentik-setup.sh first to generate credentials."
  exit 1
fi

echo "=== Configuring Nextcloud OIDC ==="

# Install OIDC Login app
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install oidc_login || true

# Configure OIDC provider
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login provider_url --value="https://auth.${DOMAIN}/application/o/nextcloud/"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login client_id --value="$OIDC_CLIENT_ID"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login client_secret --value="$OIDC_CLIENT_SECRET"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login login_type --value="username"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login auto_redirect --value="true"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login hide_password_form --value="true"

# Map Authentik groups to Nextcloud groups
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set oidc_login group_mapping --value='{"homelab-admins":"admin","homelab-users":"users"}'

echo "[OK] Nextcloud OIDC configured successfully."
echo "     Provider URL: https://auth.${DOMAIN}/application/o/nextcloud/"
echo "     Client ID: ${OIDC_CLIENT_ID}"
echo "     Restart Nextcloud: docker compose restart nextcloud"