#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Uptime Kuma Setup Script
# Automatically create monitors and status page.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DOMAIN=${DOMAIN:-yourdomain.com}
KUMA_URL="http://localhost:3001"

echo "Waiting for Uptime Kuma to be ready..."
for i in {1..30}; do
  if curl -s "$KUMA_URL" > /dev/null; then
    echo "Uptime Kuma is ready!"
    break
  fi
  sleep 2
done

echo "Installing uptime-kuma-api python package..."
pip3 install uptime-kuma-api || {
  echo "Please install python3 and pip3, then run: pip3 install uptime-kuma-api"
  exit 1
}

python3 <<EOF
import sys
import time
from uptime_kuma_api import UptimeKumaApi, MonitorType

api = UptimeKumaApi('$KUMA_URL')

# Try to setup if not already done
try:
    api.setup('admin', 'Admin123!@#')
except Exception as e:
    pass

api.login('admin', 'Admin123!@#')

# 1. Setup ntfy notification
notification_id = None
for n in api.get_notifications():
    if n['name'] == 'ntfy':
        notification_id = n['id']
        break

if not notification_id:
    # Add ntfy notification
    res = api.add_notification(
        name="ntfy",
        type="ntfy",
        isDefault=True,
        ntfyserver="https://ntfy.${DOMAIN}",
        ntfytopic="homelab_uptime",
        ntfyPriority=3
    )
    notification_id = res['msg']

# 2. Add Monitors
services = [
    ('Traefik', 'http://traefik:8080/ping'),
    ('Prometheus', 'http://prometheus:9090/-/healthy'),
    ('Grafana', 'http://grafana:3000/api/health'),
    ('Loki', 'http://loki:3100/ready'),
    ('Alertmanager', 'http://alertmanager:9093/-/healthy'),
    ('Authentik', 'http://authentik:9000/-/health/ready/'),
    ('Portainer', 'http://portainer:9000/api/system/info')
]

existing_monitors = {m['name']: m['id'] for m in api.get_monitors()}
monitor_ids = []

for name, url in services:
    if name not in existing_monitors:
        res = api.add_monitor(
            type=MonitorType.HTTP,
            name=name,
            url=url,
            maxretries=3,
            interval=60,
            notificationIDList=[notification_id] if notification_id else []
        )
        monitor_ids.append(res['msg'])
    else:
        monitor_ids.append(existing_monitors[name])

# 3. Create Status Page
slug = 'default'
try:
    api.add_status_page(slug, 'HomeLab Status')
except Exception:
    pass

# Map domain to status page
api.save_status_page(
    slug=slug,
    title="HomeLab Status",
    domainName="status.${DOMAIN}",
    published=True
)

print("Uptime Kuma monitors and status page created.")
EOF
