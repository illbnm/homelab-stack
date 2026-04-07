#!/bin/bash
# Download Grafana dashboards from Grafana.com
# Usage: ./download-dashboards.sh

DASHBOARDS_DIR="../config/grafana/dashboards"
mkdir -p "$DASHBOARDS_DIR"

# Dashboard IDs from the bounty requirements
declare -A DASHBOARDS=(
  ["node-exporter-full.json"]="1860"
  ["docker-container-metrics.json"]="179"
  ["traefik-official.json"]="17346"
  ["loki-dashboard.json"]="13639"
  ["uptime-kuma.json"]="18278"
)

for dashboard_file in "${!DASHBOARDS[@]}"; do
  dashboard_id="${DASHBOARDS[$dashboard_file]}"
  echo "Downloading dashboard $dashboard_id -> $dashboard_file"

  # Download dashboard JSON from Grafana.com
  curl -s "https://grafana.com/api/dashboards/${dashboard_id}/revisions/latest/download" \
    -o "$DASHBOARDS_DIR/$dashboard_file"

  if [ $? -eq 0 ]; then
    echo "✓ Downloaded $dashboard_file"
  else
    echo "✗ Failed to download $dashboard_file"
  fi
done

echo ""
echo "Dashboard download complete!"
echo "Files saved to: $DASHBOARDS_DIR"
ls -lh "$DASHBOARDS_DIR"
