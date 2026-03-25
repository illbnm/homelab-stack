#!/bin/bash
# uptime-kuma-setup.sh - Auto-configure Uptime Kuma monitors
# Run this script after Uptime Kuma is running to auto-create monitors

set -e

UPKUMA_URL="${UPKUMA_URL:-http://uptime-kuma:3001}"
UPKUMA_USERNAME="${UPTIME_KUMA_USERNAME:-admin}"
UPKUMA_PASSWORD="${UPTIME_KUMA_PASSWORD:-changeme}"
NTFY_HOST="${NTFY_HOST:-ntfy}"

echo "=== Uptime Kuma Setup ==="
echo "URL: ${UPKUMA_URL}"

# Wait for Uptime Kuma to be ready
echo "Waiting for Uptime Kuma to be ready..."
until curl -sf "${UPKUMA_URL}" >/dev/null 2>&1; do
    echo "  Waiting..."
    sleep 5
done
echo "Uptime Kuma is ready!"

# Login to get token
echo "Logging in..."
TOKEN=$(curl -s -X POST "${UPKUMA_URL}/api/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${UPKUMA_USERNAME}\",\"password\":\"${UPKUMA_PASSWORD}\"}" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo "Failed to login. Please check credentials."
    exit 1
fi

echo "Login successful!"

# Create notification channel
echo "Creating ntfy notification channel..."
curl -s -X POST "${UPKUMA_URL}/api/notifications" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"ntfy\",
        \"type\": \"ntfy\",
        \"isDefault\": true,
        \"config\": {
            \"hostname\": \"${NTFY_HOST}\",
            \"topic\": \"homelab-uptime\",
            \"method\": \"POST\"
        }
    }" >/dev/null

echo "Notification channel created!"

# List of services to monitor
SERVICES=(
    "traefik:http://traefik:80/api/version:Traefik API"
    "portainer:http://portainer:9000/api/status:Portainer"
    "grafana:http://grafana:3000/api/health:Grafana"
    "prometheus:http://prometheus:9090/-/healthy:Prometheus"
    "loki:http://loki:3100/ready:Loki"
    "alertmanager:http://alertmanager:9093/-/healthy:Alertmanager"
    "ntfy:http://ntfy:80/v1/health:ntfy"
    "postgres:http://postgres:5432:PostgreSQL"
    "redis:http://redis:6379:Redis"
)

# Create monitors
echo "Creating monitors..."
for service in "${SERVICES[@]}"; do
    IFS=':' read -r name url display_name <<< "$service"

    echo "  Creating monitor: ${display_name}"

    # Extract path from URL for heartbeat
    path=$(echo "$url" | sed 's/[^/]*\/\/[^/]*//')

    curl -s -X POST "${UPKUMA_URL}/api/monitors" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${display_name}\",
            \"type\": \"http\",
            \"url\": \"${url}\",
            \"interval\": 60,
            \"retries\": 3,
            \"notificationIDList\": [1],
            \"ignoreTls\": true
        }" >/dev/null 2>&1 || true
done

echo ""
echo "=== Setup Complete! ==="
echo "Access Uptime Kuma at: ${UPKUMA_URL}"
echo "Status page: ${UPKUMA_URL}/status"
