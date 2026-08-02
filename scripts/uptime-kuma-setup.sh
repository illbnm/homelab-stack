#!/bin/bash
# Automatically sets up Uptime Kuma monitors using the Python uptime-kuma-api

URL="http://uptime-kuma:3001"
USERNAME=$1
PASSWORD=$2

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: ./uptime-kuma-setup.sh <admin_user> <admin_pass>"
  exit 1
fi

echo "Setting up Uptime Kuma monitors..."

# Create a python script to run inside a temporary container
cat << 'EOF' > /tmp/kuma-setup.py
import sys
from uptime_kuma_api import UptimeKumaApi, MonitorType

url = sys.argv[1]
user = sys.argv[2]
password = sys.argv[3]

api = UptimeKumaApi(url)
api.login(user, password)

services = [
    ("Traefik", "http://traefik:8080/ping"),
    ("Portainer", "http://portainer:9000"),
    ("Nextcloud", "http://nextcloud-web:80/status.php"),
    ("Gitea", "http://gitea:3000/api/healthz"),
    ("Vaultwarden", "http://vaultwarden:80/alive"),
    ("Grafana", "http://grafana:3000/api/health"),
    ("Prometheus", "http://prometheus:9090/-/healthy"),
]

for name, target in services:
    try:
        api.add_monitor(
            type=MonitorType.HTTP,
            name=name,
            url=target,
            interval=60,
            retryInterval=30,
            maxretries=3
        )
        print(f"Added monitor for {name}")
    except Exception as e:
        print(f"Skipped {name} (may already exist or error): {e}")

api.disconnect()
EOF

# Run it using a lightweight python image
docker run --rm -v /tmp/kuma-setup.py:/tmp/kuma-setup.py --network proxy python:3.11-alpine sh -c "pip install uptime-kuma-api && python /tmp/kuma-setup.py $URL $USERNAME $PASSWORD"

echo "Done!"
