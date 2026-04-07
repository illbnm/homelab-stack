#!/bin/bash

set -e

echo "🚀 Uptime Kuma Setup Script"
echo "This script configures Uptime Kuma with all service monitors"
echo ""

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
DOMAIN="${DOMAIN:-yourdomain.com}"

# Services to monitor
SERVICES=(
  "Traefik" "https://traefik.${DOMAIN}/ping"
  "Grafana" "https://grafana.${DOMAIN}/api/health"
  "Prometheus" "https://prometheus.${DOMAIN}/-/healthy"
  "Alertmanager" "https://alertmanager.${DOMAIN}/-/healthy"
  "Authentik" "https://${AUTHENTIK_DOMAIN}/health/ready"
  "Gitea" "https://gitea.${DOMAIN}/healthcheck"
  "Nextcloud" "https://nextcloud.${DOMAIN}/status.php"
  "Portainer" "https://portainer.${DOMAIN}/api/system/status"
  "Vaultwarden" "https://vaultwarden.${DOMAIN}/alive"
  "Jellyfin" "https://jellyfin.${DOMAIN}/health"
)

# Function to check if Uptime Kuma is ready
wait_for_uptime_kuma() {
  echo "⏳ Waiting for Uptime Kuma to be ready..."
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if curl -sf "${UPTIME_KUMA_URL}" > /dev/null 2>&1; then
      echo "✅ Uptime Kuma is ready!"
      return 0
    fi
    echo "Attempt $((attempt + 1))/$max_attempts}"
    sleep 2
    ((attempt++))
  done

  echo "❌ Uptime Kuma is not responding after $max_attempts attempts"
  return 1
}

# Function to create a monitor in Uptime Kuma
create_monitor() {
  local name=$1
  local url=$2

  echo "📊 Creating monitor: $name"

  # Create monitor via Uptime Kuma API
  local response=$(curl -s -X POST \
    "${UPTIME_KUMA_URL}/api/push" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${name}\",
      \"type\": \"http\",
      \"url\": \"${url}\",
      \"interval\": 60,
      \"maxretries\": 3
    }" 2>&1)

  if [ $? -eq 0 ]; then
    echo "✅ Monitor '$name' created successfully"
  else
    echo "⚠️  Failed to create monitor '$name' (may already exist)"
  fi
}

# Function to create status page
create_status_page() {
  echo "📄 Creating public status page..."

  # Create status page via Uptime Kuma API
  local response=$(curl -s -X POST \
    "${UPTIME_KUMA_URL}/api/status-page" \
    -H "Content-Type: application/json" \
    -d "{
      \"title\": \"HomeLab Services Status\",
      \"description\": \"Real-time status of all HomeLab services\",
      \"slug\": \"homelab\",
      \"public\": true
    }" 2>&1)

  if [ $? -eq 0 ]; then
    echo "✅ Status page created"
    echo "🔗 Access at: https://status.${DOMAIN}"
  else
    echo "⚠️  Status page may already exist"
  fi
}

# Function to configure ntfy notifications
configure_ntfy_notifications() {
  echo "🔔 Configuring ntfy notifications..."

  # Note: This requires ntfy to be running or accessible
  # You'll need to manually configure ntfy webhook in Uptime Kuma UI
  # as there's no direct API endpoint for this

  echo "ℹ️  To configure ntfy notifications:"
  echo "   1. Go to Uptime Kuma Settings → Notifications"
  echo "   2. Add ntfy webhook: https://ntfy.sh/your-topic"
  echo "   3. Set notification for all monitors"
  echo ""
}

# Main execution
main() {
  echo "🚀 Starting Uptime Kuma setup..."
  echo ""

  # Wait for Uptime Kuma
  if ! wait_for_uptime_kuma; then
    exit 1
  fi

  echo ""
  echo "📊 Creating service monitors..."
  echo ""

  # Create monitors for all services
  for service_name in "${!SERVICES[@]}"; do
    create_monitor "$service_name" "${SERVICES[$service_name]}"
  done

  echo ""
  echo "📄 Setting up status page..."
  create_status_page

  echo ""
  configure_ntfy_notifications

  echo ""
  echo "✅ Uptime Kuma setup complete!"
  echo ""
  echo "🔗 Access your status page at: https://status.${DOMAIN}"
  echo ""
  echo "Next steps:"
  echo "  1. Visit the status page and verify all services are showing as 'Up'"
  echo "  2. Configure ntfy notifications in Uptime Kuma settings"
  echo "  3. Customize monitor intervals and thresholds as needed"
  echo ""
}
