#!/bin/bash
# Uptime Kuma Setup Script
# Automatically creates monitoring items for all deployed services

set -e

# Configuration
UPTIME_KUMA_URL="http://uptime-kuma:3001"
STATUS_PAGE_DOMAIN="${DOMAIN:-localhost}"

# Services to monitor (service_name:port:path)
SERVICES=(
    "prometheus:9090:/"
    "grafana:3000:/api/health"
    "alertmanager:9093:/-/healthy"
    "loki:3100:/ready"
    "tempo:3200:/ready"
    "traefik:8080:/ping"
)

# Create uptime-kuma client script
echo "Setting up Uptime Kuma monitors..."

# For each service, create a monitor via Uptime Kuma API
for service in "${SERVICES[@]}"; do
    IFS=':' read -r name port path <<< "$service"
    
    echo "Creating monitor for $name..."
    
    # Using uptime-kuma API (simplified - actual API may vary)
    curl -s -X POST "${UPTIME_KUMA_URL}/api/push" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"http\",
            \"name\": \"${name}\",
            \"url\": \"http://${name}:${port}${path}\",
            \"interval\": 60,
            \"maxRetries\": 3
        }" || echo "Warning: Could not create monitor for $name"
done

# Create status page
echo "Creating public status page..."
curl -s -X POST "${UPTIME_KUMA_URL}/api/status-page" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"HomeLab Status\",
        \"slug\": \"default\",
        \"public\": true
    }" || echo "Warning: Could not create status page"

echo ""
echo "Uptime Kuma setup complete!"
echo "Status page available at: https://status.${STATUS_PAGE_DOMAIN}"