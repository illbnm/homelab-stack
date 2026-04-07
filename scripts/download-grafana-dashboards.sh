#!/bin/bash

set -e

echo "🎨 Downloading Grafana dashboards for provisioning..."

# Dashboard IDs from grafana.com
# 1860: Node Exporter Full
# 179: Docker Container Monitoring
# 17346: Traefik Official Standalone
# 13639: Loki Dashboard
# 18278: Uptime Kuma
DASHBOARDS=(
  "1860"
  "179"
  "17346"
  "13639"
  "18278"
)

DASHBOARD_DIR="$(pwd)/bounty-work/config/grafana/dashboards"

# Function to download a dashboard by ID
download_dashboard() {
  local dashboard_id=$1

  echo "📊 Downloading dashboard $dashboard_id..."

  local output_file="$DASHBOARD_DIR/dashboard-${dashboard_id}.json"

  # Download from Grafana.com
  local download_url="https://grafana.com/api/dashboards/${dashboard_id}/revisions/latest/download"

  if curl -sf "$download_url" -o "$output_file" 2>/dev/null; then
    echo "✅ Dashboard $dashboard_id downloaded successfully"
    return 0
  else
    echo "❌ Failed to download dashboard $dashboard_id"
    return 1
  fi
}

# Function to verify dashboards exist
verify_dashboards() {
  echo "🔍 Verifying downloaded dashboards..."
  local count=0
  
  for dashboard_id in "${DASHBOARDS[@]}"; do
    local file="$DASHBOARD_DIR/dashboard-${dashboard_id}.json"
    if [ -f "$file" ]; then
      echo "  ✅ Dashboard $dashboard_id exists"
      count=$((count + 1))
    else
      echo "  ❌ Dashboard $dashboard_id missing"
    fi
  done
  
  echo ""
  echo "📊 Total dashboards: $count/${#DASHBOARDS[@]}"
}

# Function to display usage
usage() {
  echo ""
  echo "📊 Grafana Dashboard Download Script"
  echo ""
  echo "Usage: $0"
  echo ""
  echo "This script will download all required dashboards for the observability stack."
  echo "Dashboards will be saved to: $DASHBOARD_DIR"
  echo ""
}

# Main execution
main() {
  # Check dependencies
  if ! command -v curl &>/dev/null; then
    echo "❌ curl is not installed"
    exit 1
  fi

  # Parse arguments
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
    exit 0
  fi

  # Create dashboard directory
  mkdir -p "$DASHBOARD_DIR"

  # Download all dashboards
  echo "📥 Downloading dashboards from grafana.com..."
  echo ""
  for dashboard_id in "${DASHBOARDS[@]}"; do
    download_dashboard "$dashboard_id"
  done

  # Verify downloads
  echo ""
  verify_dashboards

  echo ""
  echo "✅ Dashboard download complete!"
  echo ""
  echo "📚 Downloaded ${#DASHBOARDS[@]} dashboards"
  echo "📂 Location: $DASHBOARD_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Start/restart Grafana: docker-compose restart grafana"
  echo "  2. Access dashboards at: https://grafana.\${DOMAIN}"
  echo ""
}

# Run main function
main "$@"
