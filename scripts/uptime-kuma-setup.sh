#!/usr/bin/env bash
set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_USER="${UPTIME_KUMA_USER:-admin}"
UPTIME_KUMA_PASS="${UPTIME_KUMA_PASS:-changeme}"

DOMAIN="${DOMAIN:-example.com}"

MONITORED_SERVICES=(
  "traefik:https://traefik.${DOMAIN}:443"
  "grafana:https://grafana.${DOMAIN}:443"
  "prometheus:https://prometheus.${DOMAIN}:443"
  "alertmanager:https://alertmanager.${DOMAIN}:443"
  "gitea:https://gitea.${DOMAIN}:443"
  "nextcloud:https://nextcloud.${DOMAIN}:443/status.php"
  "jellyfin:https://jellyfin.${DOMAIN}:443/health"
  "adguard:https://adguard.${DOMAIN}:443"
  "ntfy:https://ntfy.${DOMAIN}:443/v1/health"
  "uptime-kuma:https://status.${DOMAIN}:443"
)

echo "Setting up Uptime Kuma monitors..."
echo "NOTE: This script requires Uptime Kuma to be running with initial admin setup."
echo "      Open https://status.${DOMAIN} first to create your admin account."
echo ""

for entry in "${MONITORED_SERVICES[@]}"; do
  IFS=':' read -r name url <<< "$entry"
  echo "  Would add monitor: $name → $url"
done

echo ""
echo "Uptime Kuma does not have a public REST API for creating monitors."
echo "Use the web UI at https://status.${DOMAIN} to add monitors manually,"
echo "or use the Uptime Kuma API client (npm install uptime-kuma-api)."
echo ""
echo "To create a public status page:"
echo "  1. Open https://status.${DOMAIN}"
echo "  2. Go to Status Pages → New Status Page"
echo "  3. Set slug: 'public' (accessible at https://status.${DOMAIN}/status/public)"
echo "  4. Add all monitored services"
echo "  5. Save and publish"