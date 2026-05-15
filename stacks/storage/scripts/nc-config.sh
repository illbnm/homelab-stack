#!/bin/bash
# =============================================================================
# Nextcloud Post-Install Configuration
# Configures trusted_proxies, overwriteprotocol, default_phone_region, and OIDC
# =============================================================================
set -euo pipefail

CONFIG_FILE="/var/www/html/config/config.php"

echo "[nc-config] Waiting for Nextcloud to be installed..."
until [ -f "$CONFIG_FILE" ]; do
    sleep 5
done
sleep 10
echo "[nc-config] Nextcloud config found. Applying settings..."

cd /var/www/html

# Trusted proxies (Traefik reverse proxy)
if [ -n "${TRUSTED_PROXIES:-}" ]; then
    php occ config:system:set trusted_proxies 0 --value="${TRUSTED_PROXIES}"
    echo "[nc-config] Set trusted_proxies: ${TRUSTED_PROXIES}"
fi

# Overwrite protocol (force HTTPS behind reverse proxy)
php occ config:system:set overwriteprotocol --value="https"
echo "[nc-config] Set overwriteprotocol: https"

# Overwrite CLI URL
if [ -n "${DOMAIN:-}" ]; then
    php occ config:system:set overwrite.cli.url --value="https://nextcloud.${DOMAIN}"
    echo "[nc-config] Set overwrite.cli.url: https://nextcloud.${DOMAIN}"
fi

# Default phone region
DEFAULT_PHONE_REGION="${DEFAULT_PHONE_REGION:-CN}"
php occ config:system:set default_phone_region --value="${DEFAULT_PHONE_REGION}"
echo "[nc-config] Set default_phone_region: ${DEFAULT_PHONE_REGION}"

# Redis configuration
if [ -n "${REDIS_HOST:-}" ]; then
    php occ config:system:set redis host --value="${REDIS_HOST}"
    php occ config:system:set redis port --value="${REDIS_PORT:-6379}" --type=integer
    if [ -n "${REDIS_PASSWORD:-}" ]; then
        php occ config:system:set redis password --value="${REDIS_PASSWORD}"
    fi
    php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
    php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
    echo "[nc-config] Configured Redis cache and locking"
fi

# Install OIDC / SSO app if Authentik is configured
if [ -n "${OIDC_PROVIDER_URL:-}" ]; then
    echo "[nc-config] Installing user_oidc app..."
    php occ app:install user_oidc 2>/dev/null || php occ app:enable user_oidc 2>/dev/null || true

    php occ user_oidc:provider \
        --clientid="${OIDC_CLIENT_ID}" \
        --clientsecret="${OIDC_CLIENT_SECRET}" \
        --discoveryuri="${OIDC_PROVIDER_URL}/.well-known/openid-configuration" \
        "${OIDC_DISPLAY_NAME:-Authentik SSO}" 2>/dev/null || true
    echo "[nc-config] OIDC provider registered: ${OIDC_DISPLAY_NAME:-Authentik SSO}"
fi

echo "[nc-config] Configuration complete."
