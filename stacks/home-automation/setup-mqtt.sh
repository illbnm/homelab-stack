#!/usr/bin/env bash
# =============================================================================
# setup-mqtt.sh — Initialize Mosquitto MQTT users and passwords
#
# Usage:
#   cd stacks/home-automation
#   chmod +x setup-mqtt.sh
#   ./setup-mqtt.sh
#
# Reads MQTT_USER and MQTT_PASSWORD from .env (or ../../.env)
# Creates password file for Mosquitto with all required service accounts.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWD_FILE="${SCRIPT_DIR}/config/mosquitto/passwd"

# Load .env
if [ -f "${SCRIPT_DIR}/../../.env" ]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../../.env"
elif [ -f "${SCRIPT_DIR}/.env" ]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
else
    echo "ERROR: No .env file found. Copy .env.example to .env and fill values."
    exit 1
fi

MQTT_PASSWORD="${MQTT_PASSWORD:-changeme}"

echo "==> Creating Mosquitto password file..."

# Create empty passwd file
: > "${PASSWD_FILE}"

# Add users (mosquitto_passwd -b uses batch mode)
# If mosquitto_passwd is not installed locally, use Docker
if command -v mosquitto_passwd &>/dev/null; then
    PASSWD_CMD="mosquitto_passwd"
else
    echo "    Using Docker for mosquitto_passwd..."
    PASSWD_CMD="docker run --rm -v ${PASSWD_FILE}:/tmp/passwd eclipse-mosquitto:2.0.20 mosquitto_passwd"
fi

# Service accounts
declare -A USERS=(
    ["homeassistant"]="${MQTT_PASSWORD}"
    ["zigbee2mqtt"]="${MQTT_PASSWORD}"
    ["nodered"]="${MQTT_PASSWORD}"
    ["esphome"]="${MQTT_PASSWORD}"
)

for user in "${!USERS[@]}"; do
    echo "    Adding user: ${user}"
    ${PASSWD_CMD} -b "${PASSWD_FILE}" "${user}" "${USERS[${user}]}"
done

echo "==> Password file created at ${PASSWD_FILE}"
echo "==> Restart Mosquitto to apply: docker compose restart mosquitto"
