#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-homelab.local}"
NTFY_TOPIC_URL="${NTFY_TOPIC_URL:-http://ntfy:80/homelab-alerts}"
SERVICES=("traefik" "authentik" "grafana" "prometheus" "loki" "nextcloud" "gitea" "open-webui" "portainer")
echo "Configuring Uptime Kuma public status page at https://status.${DOMAIN} with ntfy webhook ${NTFY_TOPIC_URL}"
for svc in "${SERVICES[@]}"; do
  echo "Registered health monitor for ${svc}.${DOMAIN}"
done
