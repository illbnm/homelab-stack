#!/usr/bin/env bash
# uptime-kuma-setup.sh — Auto-configure Uptime Kuma monitors via API
# Intended to run after docker-compose up, once Uptime Kuma is healthy
#
# Usage:
#   ./scripts/uptime-kuma-setup.sh [UPTIME_KUMA_URL] [NTFY_TOPIC]
#   Or set environment variables:
#     UPTIME_KUMA_URL, UPTIME_KUMA_API_KEY, NTFY_TOPIC, NTFY_SERVER
#
# Environment Variables:
#   UPTIME_KUMA_URL    — Base URL of Uptime Kuma (default: http://localhost:3001)
#   UPTIME_KUMA_API_KEY — API key from Settings → API Keys (required for monitor creation)
#   NTFY_TOPIC         — ntfy.sh topic for notifications (default: homelab-alerts)
#   NTFY_SERVER        — ntfy.sh server URL (default: https://ntfy.sh)

set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-${1:-http://localhost:3001}}"
UPTIME_KUMA_API_KEY="${UPTIME_KUMA_API_KEY:-}"
NTFY_TOPIC="${NTFY_TOPIC:-${2:-homelab-alerts}}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# List of services to monitor: hostname:port:display_name:monitor_type
SERVICES=(
  "prometheus:9090:Prometheus:http"
  "grafana:3000:Grafana:http"
  "loki:3100:Loki:http"
  "alertmanager:9093:Alertmanager:http"
  "traefik:8080:Traefik:http"
  "cadvisor:8080:cAdvisor:http"
  "node-exporter:9100:NodeExporter:http"
  "authentik:9000:Authentik:http"
  "nextcloud:80:Nextcloud:http"
  "gitea:3000:Gitea:http"
  "tempo:3200:Tempo:http"
  "grafana-oncall:8080:GrafanaOnCall:http"
  "postgres-oncall:5432:PostgresOnCall:tcp"
  "redis-oncall:6379:RedisOnCall:tcp"
)

# Health check paths for specific services
declare -A HEALTH_PATHS
HEALTH_PATHS["Prometheus"]="/-/healthy"
HEALTH_PATHS["Grafana"]="/api/health"
HEALTH_PATHS["Loki"]="/ready"
HEALTH_PATHS["Alertmanager"]="/-/healthy"
HEALTH_PATHS["Traefik"]="/ping"
HEALTH_PATHS["cAdvisor"]="/healthz"
HEALTH_PATHS["NodeExporter"]="/metrics"
HEALTH_PATHS["Authentik"]="/-/healthcheck/live/"
HEALTH_PATHS["Nextcloud"]="/status.php"
HEALTH_PATHS["Gitea"]="/"
HEALTH_PATHS["Tempo"]="/ready"
HEALTH_PATHS["GrafanaOnCall"]="/health"

# Get API key interactively if not set
get_api_key() {
  if [[ -z "$UPTIME_KUMA_API_KEY" ]]; then
    echo ""
    echo "⚠️  UPTIME_KUMA_API_KEY not set."
    echo "   To create monitors automatically:"
    echo "   1. Open Uptime Kuma at: $UPTIME_KUMA_URL"
    echo "   2. Go to Settings → API Keys → Create a new API key"
    echo "   3. Export it: export UPTIME_KUMA_API_KEY='your-key'"
    echo "   4. Re-run this script"
    echo ""
    return 1
  fi
  return 0
}

# Wait for Uptime Kuma to be ready
wait_for_uptime_kuma() {
  echo "⏳ Waiting for Uptime Kuma to be ready..."
  MAX_WAIT=120
  WAITED=0
  until curl -sf "$UPTIME_KUMA_URL/api/feed" > /dev/null 2>&1 || curl -sf "$UPTIME_KUMA_URL" > /dev/null 2>&1; do
    sleep 5
    WAITED=$((WAITED + 5))
    echo "  Still waiting... (${WAITED}s/${MAX_WAIT}s)"
    if [[ $WAITED -ge $MAX_WAIT ]]; then
      echo "❌ Uptime Kuma not reachable after ${MAX_WAIT}s"
      return 1
    fi
  done
  echo "✅ Uptime Kuma is ready"
  return 0
}

# Create ntfy notification channel
create_ntfy_notification() {
  local name="$1"
  local topic="$2"
  local server="$3"
  
  # Check if notification already exists
  local existing
  existing=$(curl -s -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    "$UPTIME_KUMA_URL/api/notifications" | \
    jq -r ".[] | select(.name == \"$name\") | .id" 2>/dev/null | head -1)
  
  if [[ -n "$existing" && "$existing" != "null" ]]; then
    echo "  ℹ️  Notification '$name' already exists (ID: $existing)"
    echo "$existing"
    return
  fi

  local response
  response=$(curl -s -X POST \
    -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    -H "Content-Type: application/json" \
    "$UPTIME_KUMA_URL/api/notifications" \
    -d "{
      \"name\": \"$name\",
      \"type\": \"ntfy\",
      \"enabled\": true,
      \"ntfyAccessToken\": \"\",
      \"ntfyAuthenticationMethod\": \"anonymous\",
      \"ntfyPriority\": 3,
      \"ntfyServerURL\": \"$server\",
      \"ntfyTopic\": \"$topic\"
    }")
  
  local id
  id=$(echo "$response" | jq -r '.monitorID // .id // empty' 2>/dev/null)
  if [[ -n "$id" && "$id" != "null" ]]; then
    echo "  ✅ Created notification '$name' (ID: $id)"
  else
    echo "  ⚠️  Could not verify notification creation: $response"
  fi
  echo "$id"
}

# Create a monitor
create_monitor() {
  local name="$1"
  local type="$2"
  local host="$3"
  local port="$4"
  local path="${5:-/}"
  local notification_id="${6:-}"
  
  # Check if monitor already exists
  local existing
  existing=$(curl -s -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    "$UPTIME_KUMA_URL/api/monitors" | \
    jq -r ".[] | select(.name == \"$name\") | .id" 2>/dev/null | head -1)
  
  if [[ -n "$existing" && "$existing" != "null" ]]; then
    echo "  ℹ️  Monitor '$name' already exists (ID: $existing), skipping"
    return 0
  fi

  local payload
  if [[ "$type" == "tcp" ]]; then
    payload=$(cat <<PAYLOAD
{
  "name": "$name",
  "type": 1,
  "host": "$host",
  "port": $port,
  "interval": 60,
  "maxRetries": 3,
  "timeout": 30,
  "dnsResolveType": "A",
  "dnsResolvers": "1.1.1.1",
  "notificationIDList": [${notification_id:+"$notification_id"}],
  "active": true
}
PAYLOAD
)
  else
    payload=$(cat <<PAYLOAD
{
  "name": "$name",
  "type": 3,
  "url": "http://$host:$port$path",
  "interval": 60,
  "maxRetries": 3,
  "timeout": 30,
  "notificationIDList": [${notification_id:+"$notification_id"}],
  "active": true
}
PAYLOAD
)
  fi

  local response
  response=$(curl -s -X POST \
    -H "Authorization: Bearer $UPTIME_KUMA_API_KEY" \
    -H "Content-Type: application/json" \
    "$UPTIME_KUMA_URL/api/monitors" \
    -d "$payload")

  local id
  id=$(echo "$response" | jq -r '.monitorID // .id // empty' 2>/dev/null)
  if [[ -n "$id" && "$id" != "null" ]]; then
    echo "  ✅ Created monitor '$name' (ID: $id)"
  else
    echo "  ❌ Failed to create monitor '$name': $response"
  fi
}

# Enable public status page
enable_status_page() {
  echo ""
  echo "📋 Status page configuration:"
  echo "   1. Go to: $UPTIME_KUMA_URL/status"
  echo "   2. Enable 'Enable Status Page' and set slug to 'homelab'"
  echo "   3. Select which monitors to show on the public page"
  echo "   4. Your public status page will be at: $UPTIME_KUMA_URL/status/homelab"
}

# Print help
print_help() {
  cat <<HELP
Usage: $0 [UPTIME_KUMA_URL] [NTFY_TOPIC]

Automatically configure Uptime Kuma monitors for all homelab services.

Environment Variables:
  UPTIME_KUMA_URL      Base URL of Uptime Kuma (default: http://localhost:3001)
  UPTIME_KUMA_API_KEY  API key for Uptime Kuma (required for monitor creation)
  NTFY_TOPIC           ntfy.sh topic for notifications (default: homelab-alerts)
  NTFY_SERVER          ntfy.sh server URL (default: https://ntfy.sh)

Examples:
  # With API key
  export UPTIME_KUMA_API_KEY='your-api-key-here'
  $0 http://localhost:3001 homelab-alerts

  # Dry run (no API key - shows what would be created)
  UPTIME_KUMA_API_KEY='' $0 http://localhost:3001 homelab-alerts

Services monitored:
  - Prometheus, Grafana, Loki, Tempo, Alertmanager
  - Traefik, cAdvisor, Node Exporter
  - Authentik, Nextcloud, Gitea
  - Grafana OnCall, PostgreSQL OnCall, Redis OnCall

HELP
}

main() {
  echo "=========================================="
  echo "Uptime Kuma Auto-Setup"
  echo "=========================================="
  echo "Uptime Kuma URL: $UPTIME_KUMA_URL"
  echo "Notification topic: $NTFY_TOPIC"
  echo "NTFY server: $NTFY_SERVER"
  echo ""

  # Parse --help
  for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      print_help
      exit 0
    fi
  done

  # Wait for Uptime Kuma
  if ! wait_for_uptime_kuma; then
    echo "❌ Cannot proceed without Uptime Kuma"
    exit 1
  fi

  # Try to get API key
  if ! get_api_key; then
    echo ""
    echo "📋 Services that will be monitored (dry run - no API key):"
    for entry in "${SERVICES[@]}"; do
      IFS=':' read -r host port name type <<< "$entry"
      path="${HEALTH_PATHS[$name]:-"/"}"
      echo "   - $name (http://$host:$port$path)"
    done
    echo ""
    echo "🔔 Notifications will be sent to: $NTFY_SERVER/$NTFY_TOPIC"
    enable_status_page
    exit 0
  fi

  echo ""
  echo "🔔 Creating ntfy notification channel..."
  NOTIFICATION_ID=$(create_ntfy_notification "ntfy-alerts" "$NTFY_TOPIC" "$NTFY_SERVER")
  echo ""

  echo "📡 Creating monitors for all services..."
  for entry in "${SERVICES[@]}"; do
    IFS=':' read -r host port name type <<< "$entry"
    path="${HEALTH_PATHS[$name]:-"/"}"
    create_monitor "$name" "$type" "$host" "$port" "$path" "$NOTIFICATION_ID"
  done

  echo ""
  echo "=========================================="
  echo "✅ All monitors created!"
  echo "=========================================="
  echo ""
  echo "📊 Uptime Kuma: $UPTIME_KUMA_URL"
  echo "📄 Status page: $UPTIME_KUMA_URL/status/homelab (configure slug first)"
  echo "🔔 NTFY alerts: $NTFY_SERVER/$NTFY_TOPIC"
  echo ""
  echo "Next steps:"
  echo "  1. Review monitors at: $UPTIME_KUMA_URL/maintenance"
  echo "  2. Configure notification settings in Uptime Kuma"
  echo "  3. Set up public status page: $UPTIME_KUMA_URL/status"
}

main "$@"
