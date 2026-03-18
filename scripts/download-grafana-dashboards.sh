#!/bin/bash
# Download Grafana community dashboards for provisioning
# Usage: ./scripts/download-grafana-dashboards.sh
set -euo pipefail

DASHBOARD_DIR="config/grafana/dashboards/homelab"
mkdir -p "$DASHBOARD_DIR"

# Dashboard ID → filename mapping
# 1860 = Node Exporter Full, 179 = Docker Container, 17346 = Traefik, 13639 = Loki, 18278 = Uptime Kuma
declare -A DASHBOARDS=(
    [1860]="node-exporter-full"
    [179]="docker-container"
    [17346]="traefik"
    [13639]="loki"
    [18278]="uptime-kuma"
)

for id in "${!DASHBOARDS[@]}"; do
    name="${DASHBOARDS[$id]}"
    file="${DASHBOARD_DIR}/${name}.json"
    echo "Downloading dashboard ${id} → ${name}.json ..."
    curl -sfL "https://grafana.com/api/dashboards/${id}/revisions/1/download" \
        -o "$file" && echo "  ✓ Saved" || echo "  ✗ Failed"
    # Add provisioning metadata
    if [ -f "$file" ]; then
        tmp=$(mktemp)
        jq '. + {"__inputs": [], "__requires": []}' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file" || true
    fi
done

echo ""
echo "Dashboards saved to ${DASHBOARD_DIR}/"
