#!/bin/bash
set -e

# Uptime Kuma Setup Script
# This script automatically creates monitoring items for all deployed services

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_API_KEY="${UPTIME_KUMA_API_KEY:-}"
NTFY_URL="${NTFY_URL:-http://ntfy:80}"

# Services to monitor (add more as needed)
SERVICES=(
  "traefik:http://traefik:80/ping:Traefik Reverse Proxy"
  "grafana:http://grafana:3000:Grafana Dashboard"
  "prometheus:http://prometheus:9090/-/healthy:Prometheus"
  "loki:http://loki:3100/ready:Loki Log Aggregator"
  "alertmanager:http://alertmanager:9093/-/healthy:Alertmanager"
  "authentik:http://authentik:9000/-/health:Authentik SSO"
  "nextcloud:http://nextcloud:80/status.php:Nextcloud"
  "gitea:http://gitea:3000:Gitea"
)

echo "Setting up Uptime Kuma monitors..."

# Function to add monitor
add_monitor() {
  local name=$1
  local url=$2
  local description=$3
  
  # Check if monitor already exists (by name)
  existing=$(curl -s -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    "$UPTIME_KUMA_URL/api/_monitors" | grep -c "\"name\":\"$name\"" || true)
  
  if [ "$existing" -gt "0" ]; then
    echo "Monitor '$name' already exists, skipping..."
    return
  fi
  
  # Add monitor
  result=$(curl -s -X POST \
    -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    -H "Content-Type: application/json" \
    "$UPTIME_KUMA_URL/api/add-monitor" \
    -d "{
      \"name\": \"$name\",
      \"url\": \"$url\",
      \"type\": \"http\",
      \"interval\": 60,
      \"timeout\": 10,
      \"notificationIDList\": [],
      \"description\": \"$description\",
      \"ignoreTls\": true
    }")
  
  if echo "$result" | grep -q '"ok"'; then
    echo "Created monitor: $name"
  else
    echo "Failed to create monitor: $name - $result"
  fi
}

# Wait for Uptime Kuma to be ready
echo "Waiting for Uptime Kuma to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -s -f "$UPTIME_KUMA_URL/api/ping" > /dev/null 2>&1; then
    echo "Uptime Kuma is ready!"
    break
  fi
  attempt=$((attempt + 1))
  echo "Attempt $attempt/$max_attempts: Waiting..."
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "Uptime Kuma did not become ready in time"
  exit 1
fi

# Create monitors for each service
for service in "${SERVICES[@]}"; do
  IFS=':' read -r name url description <<< "$service"
  add_monitor "$name" "$url" "$description"
done

echo "Uptime Kuma setup complete!"
