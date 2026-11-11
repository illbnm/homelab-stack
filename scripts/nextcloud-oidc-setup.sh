#!/usr/bin/env bash
# ==============================================================================
# scripts/nextcloud-oidc-setup.sh
# Configures Nextcloud user_oidc app to authenticate against Authentik OIDC
# ==============================================================================
set -euo pipefail

DRY_RUN=false
NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
DOMAIN="${DOMAIN:-homelab.example.com}"
CLIENT_ID="${NEXTCLOUD_OIDC_CLIENT_ID:-nextcloud-oidc}"
CLIENT_SECRET="${NEXTCLOUD_OIDC_CLIENT_SECRET:-}"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

DISCOVERY_URI="https://auth.${DOMAIN}/application/o/nextcloud/.well-known/openid-configuration"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[nextcloud-oidc-setup] [DRY-RUN] docker exec -u www-data ${NEXTCLOUD_CONTAINER} php occ app:install user_oidc"
  echo "[nextcloud-oidc-setup] [DRY-RUN] docker exec -u www-data ${NEXTCLOUD_CONTAINER} php occ user_oidc:provider Authentik --clientid=${CLIENT_ID} --discoveryuri=${DISCOVERY_URI}"
  exit 0
fi

if [[ -z "$CLIENT_SECRET" ]]; then
  echo "[ERROR] NEXTCLOUD_OIDC_CLIENT_SECRET must be set." >&2
  exit 1
fi

docker exec -u www-data "${NEXTCLOUD_CONTAINER}" php occ app:install user_oidc || true
docker exec -u www-data "${NEXTCLOUD_CONTAINER}" php occ app:enable user_oidc
docker exec -u www-data "${NEXTCLOUD_CONTAINER}" php occ user_oidc:provider "Authentik"   --clientid="${CLIENT_ID}"   --clientsecret="${CLIENT_SECRET}"   --discoveryuri="${DISCOVERY_URI}"   --scope="openid profile email groups"   --mapping-uid="sub"   --mapping-display-name="name"   --mapping-email="email"   --mapping-groups="groups"   --unique-uid=0
echo "[nextcloud-oidc-setup] Nextcloud OIDC provider configured."
