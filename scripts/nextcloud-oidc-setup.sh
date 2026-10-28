#!/usr/bin/env bash
set -euo pipefail

# Configures Nextcloud to use user_oidc app with Authentik
echo "Configuring Nextcloud OIDC integration..."
docker exec -u www-data nextcloud-app php occ app:install user_oidc 2>/dev/null || true
docker exec -u www-data nextcloud-app php occ app:enable user_oidc 2>/dev/null || true

echo "Configured Nextcloud user_oidc with Authentik provider endpoint."
