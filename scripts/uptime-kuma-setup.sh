#!/bin/bash
# Uptime Kuma Auto-Setup Script
# Automatically creates monitoring items for all deployed services

set -e

# Configuration
KUMA_URL="${KUMA_URL:-http://uptime-kuma:3001}"
KUMA_DATA_DIR="${KUMA_DATA_DIR:-./data/uptime-kuma}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-alerts}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Uptime Kuma Auto-Setup ===${NC}"
echo "Kuma URL: ${KUMA_URL}"
echo "Data Directory: ${KUMA_DATA_DIR}"
echo ""

# Service endpoints to monitor
declare -A SERVICES=(
    ["Prometheus"]="http://prometheus:9090/-/healthy"
    ["Grafana"]="http://grafana:3000/api/health"
    ["Loki"]="http://loki:3100/ready"
    ["Tempo"]="http://tempo:3200/ready"
    ["Alertmanager"]="http://alertmanager:9093/-/healthy"
    ["Traefik"]="http://traefik:8080/ping"
    ["Authentik"]="http://authentik:8000/-/health/live/"
    ["cAdvisor"]="http://cadvisor:8080/healthz"
    ["Node Exporter"]="http://node-exporter:9100/metrics"
)

# Function to check if service is reachable
check_service() {
    local name=$1
    local url=$2
    
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name is reachable"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $name is not reachable (will be monitored)"
        return 1
    fi
}

# Function to create monitor via Kuma API
create_monitor() {
    local name=$1
    local url=$2
    local type=${3:-http}
    
    echo "Creating monitor for: $name"
    
    # Using Kuma's internal database setup
    # In production, you would use the Kuma API or Docker volume mount
    cat >> "${KUMA_DATA_DIR}/monitors.json" << EOF
{
    "name": "${name}",
    "type": "${type}",
    "url": "${url}",
    "interval": 60,
    "timeout": 30,
    "active": true,
    "sendUrl": false,
    "resolution": 60,
    "notificationIDList": [],
    "retryInterval": 60
}
EOF
}

# Create data directory if it doesn't exist
mkdir -p "${KUMA_DATA_DIR}"

# Initialize monitors file
echo "[" > "${KUMA_DATA_DIR}/monitors.json"

# Check and create monitors
first=true
for service in "${!SERVICES[@]}"; do
    endpoint="${SERVICES[$service]}"
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "${KUMA_DATA_DIR}/monitors.json"
    fi
    
    create_monitor "$service" "$endpoint"
done

echo "]" >> "${KUMA_DATA_DIR}/monitors.json"

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Monitors configuration saved to: ${KUMA_DATA_DIR}/monitors.json"
echo ""
echo "Next steps:"
echo "1. Start Uptime Kuma with: docker-compose up -d uptime-kuma"
echo "2. Access Uptime Kuma at: http://status.\${DOMAIN}"
echo "3. Import monitors from: ${KUMA_DATA_DIR}/monitors.json"
echo ""
echo -e "${YELLOW}Note:${NC} For full automation, configure Kuma's notification settings to send alerts to ntfy topic: ${NTFY_TOPIC}"
