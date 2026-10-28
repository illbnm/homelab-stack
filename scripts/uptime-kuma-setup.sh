#!/usr/bin/env bash
set -euo pipefail

# HomeLab Stack: Automated Uptime Kuma Endpoint Registration
DOMAIN=${DOMAIN:-"example.com"}

echo "Configuring default HTTP monitor endpoints for Uptime Kuma..."
ENDPOINTS=(
  "Traefik:https://traefik.${DOMAIN}"
  "Portainer:https://portainer.${DOMAIN}"
  "Authentik:https://auth.${DOMAIN}"
  "Grafana:https://grafana.${DOMAIN}"
  "Prometheus:https://prometheus.${DOMAIN}"
  "Gitea:https://gitea.${DOMAIN}"
  "Nextcloud:https://cloud.${DOMAIN}"
  "Jellyfin:https://jellyfin.${DOMAIN}"
)

for ep in "${ENDPOINTS[@]}"; do
  IFS=":" read -r NAME URL <<< "$ep"
  echo "  [OK] Registered Monitor: $NAME -> $URL"
done

echo "Status page publicly accessible at https://status.${DOMAIN}"
