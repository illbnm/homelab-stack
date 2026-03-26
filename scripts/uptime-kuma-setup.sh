#!/bin/bash
# =============================================================================
# Uptime Kuma — Auto Setup Script
# Discovers all deployed services via Traefik API and creates monitors.
# Run this after `docker compose up -d` in the monitoring stack directory.
#
# Prerequisites:
#   - Uptime Kuma must be running and accessible at UPTIME_KUMA_URL
#   - UPTIME_KUMA_API_TOKEN must be set (generate in Uptime Kuma UI)
# =============================================================================

set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
API_TOKEN="${UPTIME_KUMA_API_TOKEN:-}"
STATE_FILE="${UPTIME_KUMA_STATE_FILE:-/tmp/uptime-kuma-monitors.json}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1" >&2; }

# Check prerequisites
if [[ -z "$API_TOKEN" ]]; then
    warn "UPTIME_KUMA_API_TOKEN not set. Skipping monitor creation."
    warn "To set up monitors:"
    echo "  1. Navigate to https://status.\${DOMAIN}"
    echo "  2. Go to Settings > API > Create API Token"
    echo "  3. Run: export UPTIME_KUMA_API_TOKEN='your-token'"
    echo "  4. Re-run this script"
    exit 0
fi

# Check Uptime Kuma is reachable
if ! curl -sf "${UPTIME_KUMA_URL}/api/entrypage" -H "Authorization: Bearer ${API_TOKEN}" > /dev/null 2>&1; then
    err "Cannot reach Uptime Kuma at ${UPTIME_KUMA_URL}"
    err "Make sure the service is running and API token is valid."
    exit 1
fi

log "Connected to Uptime Kuma at ${UPTIME_KUMA_URL}"

# Discover services from Traefik API (if Traefik is accessible)
TRAEFIK_URL="${TRAEFIK_URL:-http://traefik:8080}"

discover_traefik_services() {
    local services=()
    
    if curl -sf "${TRAEFIK_URL}/api/http/services" -o /tmp/traefik-services.json 2>/dev/null; then
        # Extract service names and their backends
        services=$(cat /tmp/traefik-services.json | \
            python3 -c "import json,sys; [print(s['name']) for s in json.load(sys.stdin) if 'loadbalancer' in str(s)]" 2>/dev/null || true)
    fi
    
    echo "$services"
}

# Create a monitor via Uptime Kuma API
create_monitor() {
    local name="$1"; local url="$2"; local type="${3:-http}"; local interval="${4:-60}"

    # Check if monitor already exists
    existing=$(curl -sf "${UPTIME_KUMA_URL}/api/lookups/active" \
        -H "Authorization: Bearer ${API_TOKEN}" 2>/dev/null || echo "[]")
    
    if echo "$existing" | grep -q "\"name\":\"${name}\"" 2>/dev/null; then
        echo "  Monitor '${name}' already exists, skipping."
        return
    fi

    local payload=$(cat <<EOF
{
  "name": "${name}",
  "type": ${type},
  "url": "${url}",
  "interval": ${interval},
  "maxretries": 3,
  "retry-interval": 1,
  "resend-interval": 0,
  "notificationIDList": {},
  "tags": ["homelab-stack", "auto-discovery"],
  "method": "GET",
  "timeout": 30,
  "dns_resolve_type": "A",
  "dns_resolve_server": "1.1.1.1",
  "docker_container": "",
  "docker_host": "",
  "invertKeyword": false,
  "keyword": "",
  "ignoreTls": false,
  "acceptAllHeaders": true,
  "allowLocalStorage": true
}
EOF
)

    response=$(curl -sf -X POST "${UPTIME_KUMA_URL}/api/monitors" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)

    if echo "$response" | grep -q '"ok"'; then
        log "Created monitor: ${name} -> ${url}"
    else
        warn "Failed to create monitor '${name}': ${response}"
    fi
}

# Default monitors for core homelab-stack services
log "Creating default service monitors..."

create_monitor "Traefik Dashboard" "https://traefik.${DOMAIN:-example.com}" "http" 60
create_monitor "Grafana" "https://grafana.${DOMAIN:-example.com}" "http" 60
create_monitor "Prometheus" "https://prometheus.${DOMAIN:-example.com}" "http" 60
create_monitor "Uptime Kuma Status" "https://status.${DOMAIN:-example.com}" "http" 60
create_monitor "Portainer" "https://portainer.${DOMAIN:-example.com}" "http" 60

# Discover Traefik services dynamically
log "Discovering services via Traefik API..."
traefik_services=$(discover_traefik_services)
if [[ -n "$traefik_services" ]]; then
    log "Found Traefik services: ${traefik_services}"
    for svc in $traefik_services; do
        # Convert service name to plausible URL
        host="${svc//-/.}.${DOMAIN:-example.com}"
        create_monitor "$svc" "https://$host" "http" 120
    done
else
    warn "Could not reach Traefik API. Only default monitors created."
fi

log "Done! Monitors created. Configure notifications in Uptime Kuma UI:"
log "  -> https://status.${DOMAIN:-example.com}/settings"
