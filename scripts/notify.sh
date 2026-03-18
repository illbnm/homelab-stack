#!/bin/bash
# Unified notification script for ntfy and Gotify
# Usage: notify.sh <topic> <title> <message> [priority]

set -e

# Configuration
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Priority mapping (1-5 for Gotify, default/max/high for ntfy)
map_priority() {
    local priority=$1
    case $priority in
        1|low)
            echo "low"
            ;;
        2|default)
            echo "default"
            ;;
        3|high)
            echo "high"
            ;;
        4|urgent)
            echo "urgent"
            ;;
        5|emergency)
            echo "max"
            ;;
        *)
            echo "default"
            ;;
    esac
}

# Parse arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo "Example: $0 homelab-alerts 'Test' 'Hello World' 3"
    exit 1
fi

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-default}

# Map priority
NTFY_PRIORITY=$(map_priority "$PRIORITY")
GOTIFY_PRIORITY=${PRIORITY:-3}

# Try ntfy first (primary notification service)
if curl -sf -X POST \
    -H "Title: $TITLE" \
    -H "Priority: $NTFY_PRIORITY" \
    -H "Tags: warning" \
    -d "$MESSAGE" \
    "${NTFY_URL}/${TOPIC}" > /dev/null 2>&1; then
    echo "✅ Notification sent via ntfy to topic: $TOPIC"
    exit 0
fi

# Fallback to Gotify if ntfy fails
if [ -n "$GOTIFY_TOKEN" ]; then
    if curl -sf -X POST \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$GOTIFY_PRIORITY}" \
        "${GOTIFY_URL}/message" > /dev/null 2>&1; then
        echo "✅ Notification sent via Gotify"
        exit 0
    fi
fi

# If both fail, try Apprise API (if available)
if curl -sf -X POST \
    -F "body=$MESSAGE" \
    -F "title=$TITLE" \
    "http://apprise:8000/notify/${TOPIC}" > /dev/null 2>&1; then
    echo "✅ Notification sent via Apprise"
    exit 0
fi

echo "❌ Failed to send notification via all available services"
exit 1
