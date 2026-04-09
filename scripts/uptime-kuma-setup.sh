#!/usr/bin/env bash
# uptime-kuma-setup.sh - Bootstrap Uptime Kuma monitors for all homelab services
# Usage: DOMAIN=homelab.local bash scripts/uptime-kuma-setup.sh
set -euo pipefail

BASE_URL="${UPTIME_KUMA_URL:-http://uptime-kuma:3001}"
USER="${UPTIME_KUMA_USER:-admin}"
PASS="${UPTIME_KUMA_PASS:-changeme}"
DOMAIN="${DOMAIN:-homelab.local}"

command -v curl >/dev/null 2>&1 || { echo "Requires curl" >&2; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "Requires jq"   >&2; exit 1; }

TOKEN=$(curl -sf -X POST "$BASE_URL/api/v2/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" | jq -r '.token')
[[ -z "$TOKEN" || "$TOKEN" == "null" ]] && { echo "Login failed"; exit 1; }

add_monitor() {
  local name="$1" url="$2"
  curl -sf -X POST "$BASE_URL/api/v2/monitors" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"http\",\"name\":\"$name\",\"url\":\"$url\",\"interval\":60,\"retryInterval\":60,\"maxretries\":3}" \
    >/dev/null && echo "Added: $name" || echo "Skip: $name (may already exist)"
}

add_monitor "Grafana"      "https://grafana.$DOMAIN/api/health"
add_monitor "Prometheus"   "https://prometheus.$DOMAIN/-/healthy"
add_monitor "Alertmanager" "http://alertmanager:9093/-/healthy"
add_monitor "Loki"         "http://loki:3100/ready"
add_monitor "Tempo"        "http://tempo:3200/ready"
add_monitor "Authentik"    "https://auth.$DOMAIN/-/health/ready/"
add_monitor "Traefik"      "https://traefik.$DOMAIN/ping"
add_monitor "Nextcloud"    "https://cloud.$DOMAIN/status.php"
add_monitor "Gitea"        "https://git.$DOMAIN/api/healthz"

echo "Done. Status page: https://status.$DOMAIN"
