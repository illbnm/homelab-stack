#!/bin/bash
# notify.sh - Unified notification script for homelab-stack
# Usage: ./notify.sh <topic> <title> <message> [priority]
# Priority: 1=min, 3=default, 5=max

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -E '^[A-Z]' "$ENV_FILE" | xargs)
fi

# Default values
NTFY_HOST="${NTFY_HOST:-ntfy}"
NTFY_PORT="${NTFY_PORT:-80}"
DOMAIN="${DOMAIN:-localhost}"

# Arguments
TOPIC="${1:-test}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message}"
PRIORITY="${4:-3}"

# Validate arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo ""
    echo "Arguments:"
    echo "  topic    - ntfy topic/channel (e.g., homelab-alerts)"
    echo "  title    - Notification title"
    echo "  message  - Notification body"
    echo "  priority - 1=min, 2=low, 3=default, 4=high, 5=max"
    echo ""
    echo "Examples:"
    echo "  $0 homelab-test \"Hello\" \"Test message\""
    echo "  $0 homelab-alerts \"Alert\" \"CPU usage high\" 5"
    exit 0
fi

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <topic> <title> <message> [priority]"
    exit 1
fi

# Build ntfy URL
NTFY_URL="http://${NTFY_HOST}:${NTFY_PORT}/${TOPIC}"

# Send notification via curl
curl -s \
    --retry 3 \
    --retry-delay 2 \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: homelab" \
    -d "${MESSAGE}" \
    "${NTFY_URL}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Notification sent: [${PRIORITY}] ${TITLE} -> ${TOPIC}"
    exit 0
else
    echo "Error: Failed to send notification"
    exit 1
fi
