#!/bin/bash

set -e

echo "🎨 Downloading Grafana dashboards for provisioning..."

DASHBOARDS=(
  "1860"
  "179"
  "17346"
  "13639"
  "18278"
)

DASHBOARD_DIR="/var/lib/grafana/dashboards"
PROVISION_DIR="/etc/grafana/provisioning/dashboards"
GRAFANA_URL="${GRAFANA_URL:-http://grafana:3000}"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_ADMIN_PASSWORD}"

# Check if Grafana is ready
echo "⏳ Waiting for Grafana to be ready..."
until curl -sf http://grafana:3000/api/health > /dev/null 2>&1; do
  echo "✅ Grafana is ready!"
  sleep 2
done

}

# Function to download a dashboard by ID
download_dashboard() {
  local dashboard_id=$1

  echo "📊 Downloading dashboard $dashboard_id..."

  local output_file="$DASHBOARD_DIR/dashboard-${dashboard_id}.json"

  local download_url="https://grafana.com/api/dashboards/${dashboard_id}/revisions/latest/download/${dashboard_id}"

  curl -sf -H "Authorization: Bearer ${GRAFANA_PASSWORD}" \
    "$download_url" \
    -o "$output_file"

  if [ $? -eq 0 ]; then
    echo "✅ Dashboard $dashboard_id downloaded successfully"
  else
    echo "❌ Failed to download dashboard $dashboard_id"
    return 1
  fi
}

}

# Function to provision dashboards directory
setup_provisioning() {
  echo "📁 Setting up dashboard provisioning..."

  # Create provisioning directory if it doesn't exist
  mkdir -p "$PROVISION_DIR"

  # Create dashboard configuration
  cat > "$PROVISION_DIR/dashboards.yml" <<EOF
apiVersion: 1
providers:
  - name: 'homelab-dashboards'
    orgId: 1
    folder: 'HomeLab'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: $DASHBOARD_DIR
      foldersFromFilesStructure: true
EOF

  echo "✅ Dashboard provisioning configured"
}

# Function to display usage
usage() {
  echo ""
  echo "📊 Grafana Dashboard Download Script"
  echo ""
  echo "Usage: $0 [GRAFANA_URL] [GRAFANA_USER] [GRAFANA_PASSWORD]"
  echo ""
  echo "Example:"
  echo "  $0 http://localhost:3000 admin password123"
  echo ""
  echo "This script will download all required dashboards for the observability stack."
  echo ""
}

# Main execution
main() {
  # Check dependencies
  if ! command -v curl &>/dev/null 2>&1; then
    echo "❌ curl is not installed"
    exit 1
  fi

  if ! command -v jq &>/dev/null 2>&1; then
    echo "❌ jq is not installed"
    exit 1
  fi

  # Parse arguments
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
    exit 0
  fi

  # Set defaults
  GRAFANA_URL="${1:-http://grafana:3000}"
  GRAFANA_USER="${2:-admin}"
  GRAFANA_PASSWORD="${3}"

  echo "Using Grafana at: $GRAFANA_URL"

  # Wait for Grafana
  wait_for_grafana

  # Create dashboard directory
  mkdir -p "$DASHBOARD_DIR"

  # Download all dashboards
  for dashboard_id in "${DASHBOARDS[@]}"; do
    download_dashboard "$dashboard_id"
  done

  # Setup provisioning
  setup_provisioning

  echo ""
  echo "✅ Dashboard download complete!"
  echo ""
  echo "📚 Downloaded ${#Dashboards[@]} dashboards:"
  for id in "${DASHboards[@]}"; do
    echo "   - Dashboard $id"
  done
  echo ""
  echo "📂 Location: $DASHBOARD_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Restart Grafana: docker restart grafana"
  echo "  2. Access dashboards at: https://grafana.\${DOMAIN}"
  echo "  3. Default credentials: ${GRAFANA_USER} / ${GRAFANA_PASSWORD}"
  echo ""
}
