#!/bin/bash
set -e

# Nextcloud OIDC configuration via occ
# Assumes Nextcloud is running in docker
docker exec -u www-data nextcloud php occ app:install sociallogin
docker exec -u www-data nextcloud php occ config:app:set sociallogin oidc_provider_url "https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/"
docker exec -u www-data nextcloud php occ config:app:set sociallogin oidc_client_id "${AUTHENTIK_NEXTCLOUD_CLIENT_ID}"
docker exec -u www-data nextcloud php occ config:app:set sociallogin oidc_client_secret "${AUTHENTIK_NEXTCLOUD_CLIENT_SECRET}"
