#!/usr/bin/env bash
# ==============================================================================
# Uptime Kuma Auto-Setup Script
# Automatically creates health monitors for all deployed homelab services
# Uses the Uptime Kuma REST API (no manual GUI interaction required)
# ==============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override via env or edit here
# ---------------------------------------------------------------------------
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_USER="${UPTIME_KUMA_USER:-admin}"
UPTIME_KUMA_PASS="${UPTIME_KUMA_PASS:-changeme}"
DOMAIN="${DOMAIN:-localhost}"

# Services to monitor: name|url|method
SERVICES=(
  "Prometheus|http://prometheus:9090/-/healthy|GET"
  "Grafana|http://grafana:3000/api/health|GET"
  "Loki|http://loki:3100/ready|GET"
  "Alertmanager|http://alertmanager:9093/-/healthy|GET"
  "Node Exporter|http://node-exporter:9100/metrics|GET"
  "cAdvisor|http://cadvisor:8080/healthz|GET"
  "Traefik|https://${DOMAIN}/|GET"
  "Uptime Kuma|http://localhost:3001|GET"
  "Grafana OnCall|http://oncall:8080/health|GET"
  "Tempo|http://tempo:3200/ready|GET"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo -e "\033[1;36m[uptime-kuma]\033[0m $*"; }
err() { echo -e "\033[1;31m[uptime-kuma]\033[0m $*" >&2; }

wait_for_service() {
  local url="$1" max_wait="${2:-60}" elapsed=0
  log "Waiting for $url ..."
  while ! curl -sf "$url" >/dev/null 2>&1; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [ "$elapsed" -ge "$max_wait" ]; then
      err "Timeout waiting for $url after ${max_wait}s"
      return 1
    fi
  done
  log "Service ready."
}

# ---------------------------------------------------------------------------
# 1. Wait for Uptime Kuma
# ---------------------------------------------------------------------------
wait_for_service "${UPTIME_KUMA_URL}" 90

# ---------------------------------------------------------------------------
# 2. Register an admin account (first-time only)
# ---------------------------------------------------------------------------
log "Setting up admin account..."
SETUP_PAYLOAD=$(cat <<JSON
{
  "username": "${UPTIME_KUMA_USER}",
  "password": "${UPTIME_KUMA_PASS}",
  "password2": "${UPTIME_KUMA_PASS}",
  "token": ""
}
JSON
)

HTTP_CODE=$(curl -s -o /tmp/uk-setup.json -w "%{http_code}" \
  -X POST "${UPTIME_KUMA_URL}/api/user/setup" \
  -H "Content-Type: application/json" \
  -d "${SETUP_PAYLOAD}" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  log "Admin account created."
else
  log "Admin account already exists or setup skipped (HTTP ${HTTP_CODE})."
fi

# ---------------------------------------------------------------------------
# 3. Login and get session token
# ---------------------------------------------------------------------------
log "Logging in..."
LOGIN_PAYLOAD=$(cat <<JSON
{
  "username": "${UPTIME_KUMA_USER}",
  "password": "${UPTIME_KUMA_PASS}",
  "token": ""
}
JSON
)

LOGIN_RESP=$(curl -s -c /tmp/uk-cookies.txt \
  -X POST "${UPTIME_KUMA_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}")

if echo "$LOGIN_RESP" | grep -q '"ok":true'; then
  log "Login successful."
else
  err "Login failed: $LOGIN_RESP"
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Create monitors for each service
# ---------------------------------------------------------------------------
log "Creating monitors for ${#SERVICES[@]} services..."

for entry in "${SERVICES[@]}"; do
  IFS='|' read -r name url method <<< "$entry"

  MONITOR_PAYLOAD=$(cat <<JSON
{
  "type": "http",
  "name": "${name}",
  "url": "${url}",
  "method": "${method}",
  "interval": 60,
  "retries": 3,
  "retryInterval": 30,
  "acceptedStatuscodes": ["200-299"],
  "keyword": "",
  "notificationIDList": {},
  "tags": []
}
JSON
  )

  RESP=$(curl -s -b /tmp/uk-cookies.txt \
    -X POST "${UPTIME_KUMA_URL}/api/monitor/add" \
    -H "Content-Type: application/json" \
    -d "${MONITOR_PAYLOAD}")

  if echo "$RESP" | grep -q '"ok":true'; then
    log "  ✓ ${name} (${url})"
  else
    log "  ⚠ ${name} — may already exist or failed"
  fi
done

# ---------------------------------------------------------------------------
# 5. Create a public status page
# ---------------------------------------------------------------------------
log "Creating public status page..."
STATUS_PAYLOAD=$(cat <<JSON
{
  "title": "HomeLab Status",
  "slug": "status",
  "public": true,
  "showPoweredBy": false,
  "domainMappingList": [],
  "icon": ""
}
JSON
)

STATUS_RESP=$(curl -s -b /tmp/uk-cookies.txt \
  -X POST "${UPTIME_KUMA_URL}/api/status-page/add" \
  -H "Content-Type: application/json" \
  -d "${STATUS_PAYLOAD}")

if echo "$STATUS_RESP" | grep -q '"ok":true'; then
  log "  ✓ Public status page created at /status"
else
  log "  ⚠ Status page may already exist"
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f /tmp/uk-cookies.txt /tmp/uk-setup.json

log "=========================================="
log " Uptime Kuma setup complete!"
log " Status page: ${UPTIME_KUMA_URL}/status"
log "=========================================="
