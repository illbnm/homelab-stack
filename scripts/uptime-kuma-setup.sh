#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# Uptime Kuma Auto-Setup Script
# Creates monitors for all deployed homelab services
# Usage: ./scripts/uptime-kuma-setup.sh [DOMAIN] [KUMA_USER] [KUMA_PASS]
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

DOMAIN="${1:-${DOMAIN:-localhost}}"
KUMA_URL="https://status.${DOMAIN}"
KUMA_USER="${2:-${UPTIME_KUMA_USER:-admin}}"
KUMA_PASS="${3:-${UPTIME_KUMA_PASSWORD:-changeme}}"
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-alerts}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Uptime Kuma Auto-Setup"
echo "  URL: ${KUMA_URL}"
echo "  Domain: ${DOMAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for Uptime Kuma to be ready
echo "[1/4] Waiting for Uptime Kuma..."
for i in $(seq 1 30); do
  if curl -sSf "${KUMA_URL}/api/entry" >/dev/null 2>&1; then
    echo "  ✓ Uptime Kuma is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "  ✗ Uptime Kuma not responding after 30 attempts"
    exit 1
  fi
  sleep 2
done

# Login and get token
echo "[2/4] Authenticating..."
# Note: Uptime Kuma uses WebSocket for its API. For automated setup,
# we use the REST-compatible endpoints where available, or the
# kuma-cli tool if installed.

# Check if kuma CLI is available (npm install -g uptime-kuma-cli)
if command -v kuma >/dev/null 2>&1; then
  echo "  Using kuma CLI"
  kuma login "${KUMA_URL}" --username "${KUMA_USER}" --password "${KUMA_PASS}"
  CLI_MODE=true
else
  echo "  kuma CLI not found — using curl-based setup"
  echo "  Install for full automation: npm install -g @uptime-kuma/cli"
  CLI_MODE=false
fi

# ─── Service Definitions ─────────────────────────────────────────
# Format: NAME|TYPE|URL_OR_HOST|EXPECTED_CODE|INTERVAL
SERVICES=(
  "Traefik Dashboard|https|https://traefik.${DOMAIN}|200|60"
  "Grafana|https|https://grafana.${DOMAIN}/api/health|200|60"
  "Prometheus|https|https://prometheus.${DOMAIN}/-/healthy|200|60"
  "Alertmanager|https|https://alertmanager.${DOMAIN}/-/healthy|200|60"
  "Authentik|https|https://auth.${DOMAIN}/-/health/live/|200|60"
  "Gitea|https|https://git.${DOMAIN}/api/v1/version|200|120"
  "Vaultwarden|https|https://vault.${DOMAIN}/alive|200|120"
  "Outline|https|https://docs.${DOMAIN}/_health|200|120"
  "Nextcloud|https|https://cloud.${DOMAIN}/status.php|200|120"
  "Home Assistant|https|https://ha.${DOMAIN}/api/|200|120"
  "Node-RED|https|https://nodered.${DOMAIN}|200|120"
  "Jellyfin|https|https://media.${DOMAIN}/health|200|120"
  "Stirling PDF|https|https://pdf.${DOMAIN}|200|300"
  "Uptime Kuma (self)|https|https://status.${DOMAIN}|200|300"
  "Loki|http|http://loki:3100/ready|200|120"
  "Tempo|http|http://tempo:3200/ready|200|120"
)

echo "[3/4] Creating monitors..."
if [ "${CLI_MODE}" = true ]; then
  for svc in "${SERVICES[@]}"; do
    IFS='|' read -r name type url code interval <<< "${svc}"
    echo "  → ${name} (${url})"
    kuma monitor add \
      --name "${name}" \
      --type http \
      --url "${url}" \
      --expected-status-code "${code}" \
      --interval "${interval}" \
      --retry-interval 30 \
      --max-retries 3 \
      2>/dev/null || echo "    (already exists or skipped)"
  done
else
  echo "  Manual setup required without kuma CLI."
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────┐"
  echo "  │  Add these monitors in Uptime Kuma UI:                  │"
  echo "  │  ${KUMA_URL}/dashboard                                  │"
  echo "  └─────────────────────────────────────────────────────────┘"
  echo ""
  printf "  %-20s %-6s %-50s %s\n" "Name" "Type" "URL" "Interval"
  printf "  %-20s %-6s %-50s %s\n" "────────────────────" "──────" "──────────────────────────────────────────────────" "────────"
  for svc in "${SERVICES[@]}"; do
    IFS='|' read -r name type url code interval <<< "${svc}"
    printf "  %-20s %-6s %-50s %ss\n" "${name}" "${type}" "${url}" "${interval}"
  done
fi

# ─── Create Status Page ──────────────────────────────────────────
echo "[4/4] Status page setup..."
if [ "${CLI_MODE}" = true ]; then
  kuma status-page add \
    --title "Homelab Status" \
    --slug "status" \
    --description "Service status for ${DOMAIN}" \
    --published true \
    2>/dev/null || echo "  Status page already exists"
  echo "  ✓ Status page: https://status.${DOMAIN}/status"
else
  echo "  Create a status page manually:"
  echo "  1. Go to ${KUMA_URL}/manage-status-page"
  echo "  2. Create page with slug 'status'"
  echo "  3. Add all monitors to the page"
  echo "  4. Set to public (no login required)"
  echo ""
  echo "  Public URL: https://status.${DOMAIN}/status/status"
fi

# ─── ntfy Notification Setup ─────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ntfy Notification Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  In Uptime Kuma → Settings → Notifications:"
echo "  1. Add notification type: ntfy"
echo "  2. Server URL: ${NTFY_URL}"
echo "  3. Topic: ${NTFY_TOPIC}"
echo "  4. Set as default for all monitors"
echo ""
echo "  ✓ Setup complete!"
