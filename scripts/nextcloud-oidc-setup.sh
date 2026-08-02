#!/bin/bash
# Automates setting up OIDC within Nextcloud via OCC

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (or via sudo)"
  exit 1
fi

CLIENT_ID=$1
CLIENT_SECRET=$2
DISCOVERY_ENDPOINT=$3

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ -z "$DISCOVERY_ENDPOINT" ]; then
  echo "Usage: ./nextcloud-oidc-setup.sh <client_id> <client_secret> <discovery_endpoint>"
  echo "Example discovery endpoint: https://auth.example.com/application/o/nextcloud/.well-known/openid-configuration"
  exit 1
fi

echo "Installing user_oidc app..."
docker exec -u www-data nextcloud-app php occ app:install user_oidc
docker exec -u www-data nextcloud-app php occ app:enable user_oidc

echo "Configuring OIDC provider 'Authentik'..."
# Provider configuration (UUID 1)
docker exec -u www-data nextcloud-app php occ user_oidc:provider Authentik -c "$CLIENT_ID" -s "$CLIENT_SECRET" -d "$DISCOVERY_ENDPOINT"

# Additional mappings
docker exec -u www-data nextcloud-app php occ config:app:set user_oidc provider-1-mapping-uid --value="preferred_username"
docker exec -u www-data nextcloud-app php occ config:app:set user_oidc provider-1-mapping-email --value="email"

echo "Done! OIDC login should now be visible on Nextcloud."
