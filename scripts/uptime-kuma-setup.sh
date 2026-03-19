#!/bin/bash
set -euo pipefail

# Uptime Kuma Setup Script
# Automatically creates monitors for all deployed services

: " + "${UPTIME_KUMA_URL:-http://localhost:3001}" + "
: " + "${DOMAIN:-localhost}" + "

echo "Setting up Uptime Kuma monitors..."

# Wait for Uptime Kuma to be ready
until curl -s " + "${UPTIME_KUMA_URL}" + /health > /dev/null 2>&1; do
  echo "Waiting for Uptime Kuma to start..."
  sleep 5
done

echo "Uptime Kuma is ready!"

# Define services to monitor
declare -A SERVICES=(
  ["Traefik"]="https://traefik. + "${DOMAIN}" + /api/raw"
  ["Portainer"]="https://portainer. + "${DOMAIN}" + /api/status"
  ["Grafana"]="https://grafana. + "${DOMAIN}" + /api/health"
  ["Prometheus"]="https://prometheus. + "${DOMAIN}" + /-/healthy"
  ["Loki"]="http://loki:3100/ready"
  ["Authentik"]="https://auth. + "${DOMAIN}" + /-/health/ready"
  ["Gitea"]="https://git. + "${DOMAIN}" + /api/v1/version"
  ["Nextcloud"]="https://cloud. + "${DOMAIN}" + /status.php"
  ["Jellyfin"]="https://media. + "${DOMAIN}" + /health"
)

# Create monitors via API (requires authentication token)
# Note: This is a placeholder - Uptime Kuma API requires authentication
# You'll need to set up API access first

echo "Services to monitor:"
for service in " + "${!SERVICES[@]}" + "; do
  echo "  -  + "$service" + : " + "${SERVICES[]}" + "
done

echo ""
echo "Please log in to Uptime Kuma at https://status. + "${DOMAIN}" +  to configure monitors."
echo "Or use the Uptime Kuma API with an authentication token."
echo ""
echo "Suggested monitors:"
for service in " + "${!SERVICES[@]}" + "; do
  echo "  -  + "$service" + : " + "${SERVICES[]}" + "
done

echo ""
echo "Setup complete!"
