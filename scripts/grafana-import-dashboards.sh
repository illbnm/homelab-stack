#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASS="${GRAFANA_ADMIN_PASSWORD:-changeme}"

DASHBOARDS=(
  "1860:Node Exporter Full"
  "179:Docker Container & Host Metrics"
  "17346:Traefik Official"
  "13639:Loki Dashboard"
  "18278:Uptime Kuma"
)

echo "Importing Grafana dashboards..."

for entry in "${DASHBOARDS[@]}"; do
  IFS=':' read -r id name <<< "$entry"
  echo -n "  Importing $name (ID: $id)... "

  response=$(curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -X POST \
    -H "Content-Type: application/json" \
    "${GRAFANA_URL}/api/dashboards/import" \
    -d "{
      \"pluginId\": \"\",
      \"overwrite\": true,
      \"dashboard\": {
        \"id\": null,
        \"uid\": \"grafana-imported-${id}\",
        \"gnetId\": ${id},
        \"gnetVersion\": \"latest\"
      },
      \"inputs\": [
        {\"name\": \"DS_PROMETHEUS\", \"type\": \"datasource\", \"pluginId\": \"prometheus\", \"value\": \"Prometheus\"},
        {\"name\": \"DS_LOKI\", \"type\": \"datasource\", \"pluginId\": \"loki\", \"value\": \"Loki\"}
      ],
      \"folderId\": 0
    }" 2>/dev/null) || true

  if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
    echo "OK"
  else
    echo "WARN (may need manual import)"
  fi
done

echo "Dashboard import complete."