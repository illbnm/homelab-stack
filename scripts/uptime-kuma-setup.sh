#!/usr/bin/env bash
#
# Uptime Kuma Auto-Setup Script
# Scans deployed stacks and creates monitors for all services
#
# Usage: ./scripts/uptime-kuma-setup.sh
# Requires: UPTIME_KUMA_URL and UPTIME_KUMA_API_KEY in .env (or prompts)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  source "$PROJECT_ROOT/.env"
fi

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_API_KEY="${UPTIME_KUMA_API_KEY:-}"

if [[ -z "$UPTIME_KUMA_API_KEY" ]]; then
  echo "Error: UPTIME_KUMA_API_KEY not set in .env"
  echo "Generate an API key in Uptime Kuma: Settings -> API Keys"
  exit 1
fi

# Function to add a monitor
add_monitor() {
  local name="$1"
  local url="$2"
  local type="http"
  local interval=60
  local expected="200"

  echo "Creating monitor: $name -> $url"

  curl -s -X POST "$UPTIME_KUMA_URL/api/monitors" \
    -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg name "$name" \
      --arg url "$url" \
      --arg type "$type" \
      --arg interval "$interval" \
      --arg expected "$expected" \
      '{
        name: $name,
        type: $type,
        config: {
          url: $url,
          method: "GET",
          expectedStatus: ($expected | tonumber),
          interval: ($interval | tonumber)
        }
      }')" > /dev/null || {
      echo "  [WARN] Failed to create monitor (may already exist)"
    }
}

# Discover services from deployed stacks
SERVICES=()

# Monitoring stack itself
SERVICES+=("Prometheus|http://prometheus:9090/-/healthy")
SERVICES+=("Grafana|http://grafana:3000/api/health")
SERVICES+=("Loki|http://loki:3100/ready")
SERVICES+=("Alertmanager|http://alertmanager:9093/-/healthy")
SERVICES+=("Tempo|http://tempo:3200/ready")
SERVICES+=("Uptime Kuma|http://uptime-kuma:3001")

# Optionally add other stacks if they are running
# Base stack
if docker compose -f "$PROJECT_ROOT/stacks/base/docker-compose.yml" ps | grep -q "traefik"; then
  SERVICES+=("Traefik|http://traefik:8080/ping")
fi

# SSO stack (Authentik)
if docker compose -f "$PROJECT_ROOT/stacks/sso/docker-compose.yml" ps | grep -q "authentik"; then
  SERVICES+=("Authentik|https://authentik.${DOMAIN:-local}/-/health/")
fi

echo "[*] Uptime Kuma auto-setup starting..."
echo "[*] Target: $UPTIME_KUMA_URL"
echo "[*] Found ${#SERVICES[@]} services to monitor."

for svc in "${SERVICES[@]}"; do
  IFS='|' read -r name url <<< "$svc"
  add_monitor "$name" "$url"
done

echo "[+] Uptime Kuma setup complete."
echo "    Status page: ${UPTIME_KUMA_URL}/status ? (public share must be enabled manually)"
echo "    Manage monitors: ${UPTIME_KUMA_URL}/manage"
