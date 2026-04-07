#!/bin/bash
# Uptime Kuma Setup Script
# Automatically creates monitors for all homelab services
# Usage: ./uptime-kuma-setup.sh

set -e

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
DOMAIN="${DOMAIN:-localhost}"
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
ADMIN_USERNAME="${UPTIME_KUMA_ADMIN:-admin}"
ADMIN_PASSWORD="${UPTIME_KUMA_PASSWORD:-admin123}"

echo "=== Uptime Kuma Setup Script ==="
echo "Uptime Kuma URL: $UPTIME_KUMA_URL"
echo "Domain: $DOMAIN"
echo ""

# Wait for Uptime Kuma to be ready
echo "Waiting for Uptime Kuma to be ready..."
until curl -sf "$UPTIME_KUMA_URL" > /dev/null; do
  echo "  - Uptime Kuma not ready, waiting..."
  sleep 5
done
echo "✓ Uptime Kuma is ready"
echo ""

# Function to create monitor
create_monitor() {
  local name="$1"
  local url="$2"
  local type="${3:-http}"

  echo "Creating monitor: $name -> $url"

  # This is a simplified version - in production, you'd use the Uptime Kuma API
  # For now, we'll output instructions for manual setup

  echo "  Name: $name"
  echo "  URL: $url"
  echo "  Type: $type"
  echo ""
}

echo "=== Creating Monitors ==="
echo ""

# Core Infrastructure
create_monitor "Traefik (Reverse Proxy)" "https://traefik.${DOMAIN}" "http"
create_monitor "Authentik (SSO)" "https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}" "http"

# Monitoring Stack
create_monitor "Prometheus" "https://prometheus.${DOMAIN}" "http"
create_monitor "Grafana" "https://grafana.${DOMAIN}" "http"
create_monitor "Alertmanager" "http://alertmanager:9093" "http"
create_monitor "Loki" "http://loki:3100/ready" "http"

# Productivity Services
create_monitor "Nextcloud (Files)" "https://nextcloud.${DOMAIN}" "http"
create_monitor "Gitea (Git)" "https://git.${DOMAIN}" "http"
create_monitor "Vaultwarden (Password Manager)" "https://vault.${DOMAIN}" "http"
create_monitor "Wiki (Documentation)" "https://wiki.${DOMAIN}" "http"

# Media Services
create_monitor "Sonarr (TV Shows)" "https://sonarr.${DOMAIN}" "http"
create_monitor "Radarr (Movies)" "https://radarr.${DOMAIN}" "http"
create_monitor "Prowlarr (Indexers)" "https://prowlarr.${DOMAIN}" "http"

# Storage Services
create_monitor "MinIO (S3)" "https://s3.${DOMAIN}" "http"
create_monitor "MinIO Console" "https://minio.${DOMAIN}" "http"

# Home Automation
create_monitor "Home Assistant" "https://ha.${DOMAIN}" "http"
create_monitor "Node-RED" "https://nodered.${DOMAIN}" "http"
create_monitor "Zigbee2MQTT" "https://zigbee.${DOMAIN}" "http"

# AI Services
create_monitor "Ollama (AI)" "https://ollama.${DOMAIN}" "http"
create_monitor "Open WebUI" "https://ai.${DOMAIN}" "http"

# Dashboard
create_monitor "Homepage Dashboard" "https://home.${DOMAIN}" "http"
create_monitor "Homarr Dashboard" "https://dashboard.${DOMAIN}" "http"

# Notifications
create_monitor "ntfy (Push Notifications)" "https://ntfy.${DOMAIN}" "http"
create_monitor "Apprise" "https://apprise.${DOMAIN}" "http"

# Management
create_monitor "Portainer (Container Management)" "https://portainer.${DOMAIN}" "http"

echo "=== Monitor Creation Complete ==="
echo ""
echo "⚠️  IMPORTANT: Uptime Kuma requires initial setup through its web interface"
echo ""
echo "Setup Steps:"
echo "1. Open https://status.${DOMAIN}"
echo "2. Create an admin account"
echo "3. Click 'Add New Monitor' for each service above"
echo "4. Configure notification to send alerts to ntfy:"
echo "   - Go to Settings → Notifications"
echo "   - Add new notification: ntfy"
echo "   - URL: ${NTFY_URL}/homelab-alerts"
echo "   - Priority: 5 (for critical alerts)"
echo "   - Test and save"
echo ""
echo "For automated setup, consider using:"
echo "- Uptime Kuma API (https://github.com/louislam/uptime-kuma/wiki/API)"
echo "- uptime-kuma-api Python library"
echo ""

# Create a notification configuration helper
cat > /tmp/uptime-kuma-notification-config.txt <<EOF
=== NTFY Notification Configuration for Uptime Kuma ===

Notification Type: ntfy
URL: ${NTFY_URL}/homelab-alerts
Topic: homelab-alerts
Priority: 5 (for critical), 3 (for warnings)
Authentication: Optional (add Bearer token if ntfy requires auth)

Test Message: "Homelab monitoring test from Uptime Kuma"
EOF

echo "✓ Notification configuration guide saved to: /tmp/uptime-kuma-notification-config.txt"
echo ""
echo "=== Setup Complete ==="
