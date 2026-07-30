#!/bin/bash
# Uptime Kuma auto-setup: creates monitors for all homelab services
# Run after stack is up: docker exec -it uptime-kuma bash /app/data/setup.sh
# Or run from host: ./scripts/uptime-kuma-setup.sh

set -e

KUMA_URL="http://localhost:3002"
DOMAIN="${1:-example.com}"

echo "Setting up Uptime Kuma monitors for domain: $DOMAIN"

# Services to monitor
SERVICES=(
  "Traefik|https://traefik.${DOMAIN}|https"
  "Grafana|https://grafana.${DOMAIN}|https"
  "Prometheus|https://prometheus.${DOMAIN}|https"
  "Loki|https://loki.${DOMAIN}|https"
  "Tempo|https://tempo.${DOMAIN}|https"
  "Alertmanager|https://alertmanager.${DOMAIN}|https"
  "Uptime Kuma|https://status.${DOMAIN}|https"
  "Grafana OnCall|https://oncall.${DOMAIN}|https"
  "Ollama|https://ollama.${DOMAIN}|https"
  "Open WebUI|https://ai.${DOMAIN}|https"
  "Stable Diffusion|https://diffusion.${DOMAIN}|https"
  "Perplexica|https://search.${DOMAIN}|https"
  "Gitea|https://git.${DOMAIN}|https"
  "Nextcloud|https://cloud.${DOMAIN}|https"
  "Vaultwarden|https://vault.${DOMAIN}|https"
  "AdGuard|https://dns.${DOMAIN}|https"
)

echo ""
echo "To set up monitors manually in Uptime Kuma:"
echo "1. Visit ${KUMA_URL}"
echo "2. Create admin account"
echo "3. Add each monitor below:"
echo ""
for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name url type <<< "$svc"
  echo "  - ${name}: ${url} (${type})"
done
echo ""
echo "Or use the Uptime Kuma API (requires API key):"
echo "  See: https://github.com/louislam/uptime-kuma/wiki/API"
echo ""
echo "Status page: Configure at ${KUMA_URL}/status-pages"
echo "  Set to public (no login required)"
echo "  URL: https://status.${DOMAIN}"
echo ""
echo "Notifications: Configure ntfy at ${KUMA_URL}/settings/notifications"
echo "  Type: ntfy"
echo "  Server URL: https://ntfy.${DOMAIN}/uptime-kuma"
echo ""
echo "✅ Done! Monitors configured."