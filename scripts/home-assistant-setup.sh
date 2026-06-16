#!/bin/bash
# home-assistant-setup.sh

set -euo pipefail

# Create MQTT password
if [ ! -f mosquitto/data/passwd ]; then
    docker compose exec mosquitto mosquitto_passwd -c /mosquitto/data/passwd "${MQTT_USER:-mqtt}" "${MQTT_PASS:-changeme}"
    echo "MQTT password created"
fi

echo "Home Automation stack setup complete!"
echo "Access Home Assistant at http://homeassistant.local:8123"
echo "or via bridge mode at https://homeassistant.${DOMAIN:-your-domain.com}"
