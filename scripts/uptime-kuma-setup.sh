#!/bin/bash
# Uptime Kuma auto-setup: create monitors for all deployed services
DOMAIN="${DOMAIN:-localhost}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-alerts}"
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"

echo "=== Uptime Kuma Monitor Setup ==="
echo "Waiting for Uptime Kuma to be ready..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3001 > /dev/null 2>&1; then
        echo "Uptime Kuma is ready!"
        break
    fi
    sleep 2
done

SERVICES=(
    "https://grafana.${DOMAIN}|Grafana Dashboard"
    "https://prometheus.${DOMAIN}|Prometheus Metrics"
    "https://uptime.${DOMAIN}|Uptime Kuma"
    "https://alerts.${DOMAIN}|Alertmanager"
)

echo ""
echo "Create the following monitors in Uptime Kuma (https://uptime.${DOMAIN}):"
echo "Configure ntfy notification: ${NTFY_URL}/${NTFY_TOPIC}"
echo ""
for svc in "${SERVICES[@]}"; do
    IFS='|' read -r url name <<< "$svc"
    echo "  - ${name}: ${url}"
done

echo ""
echo "Public status page: https://status.${DOMAIN}"
echo "=== Setup Complete ==="
