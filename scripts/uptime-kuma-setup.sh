#!/bin/bash
# =============================================================================
# uptime-kuma-setup.sh - Auto-configure Uptime Kuma monitors
# Usage: ./uptime-kuma-setup.sh
# =============================================================================

set -euo pipefail

# Configuration
UPTIME_URL="${UPTIME_URL:-http://localhost:3001}"
UPTIME_USER="${UPTIME_USER:-admin}"
UPTIME_PASS="${UPTIME_PASS:-}"

# Services to monitor
declare -a SERVICES=(
    "traefik:Traefik Reverse Proxy:https://traefik.${DOMAIN}/api/rawdata"
    "grafana:Grafana Dashboard:https://grafana.${DOMAIN}/api/health"
    "prometheus:Prometheus:https://prometheus.${DOMAIN}/-/healthy"
    "alertmanager:Alertmanager:https://alertmanager.${DOMAIN}/-/healthy"
    "gitea:Gitea Git:https://git.${DOMAIN}/api/v1/version"
    "vaultwarden:Vaultwarden:https://vault.${DOMAIN}/alive"
    "nextcloud:Nextcloud:https://cloud.${DOMAIN}/status.php"
    "jellyfin:Jellyfin Media:https://media.${DOMAIN}/health"
    "adguard:AdGuard DNS:https://dns.${DOMAIN}/"
)

echo "=== Uptime Kuma Setup ==="

# Login to get token
echo "Logging in to Uptime Kuma..."
TOKEN=$(curl -sf -X POST "${UPTIME_URL}/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${UPTIME_USER}\",\"password\":\"${UPTIME_PASS}\"}" | jq -r '.token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "Failed to login to Uptime Kuma"
    exit 1
fi

echo "✅ Logged in successfully"

# Create monitors
for service in "${SERVICES[@]}"; do
    IFS=':' read -r NAME FRIENDLY_NAME URL <<< "$service"
    
    echo "Creating monitor: ${FRIENDLY_NAME}"
    
    RESPONSE=$(curl -sf -X POST "${UPTIME_URL}/api/status-page/monitor" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"http\",
            \"name\": \"${FRIENDLY_NAME}\",
            \"url\": \"${URL}\",
            \"interval\": 60,
            \"maxretries\": 3,
            \"notificationIDList\": {}
        }")
    
    if echo "$RESPONSE" | jq -e '.monitorID' > /dev/null 2>&1; then
        echo "  ✅ Created: ${FRIENDLY_NAME}"
    else
        echo "  ❌ Failed: ${FRIENDLY_NAME}"
    fi
done

echo ""
echo "=== Setup Complete ==="
echo "Access Uptime Kuma: https://status.${DOMAIN}"
