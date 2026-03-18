#!/bin/bash

# Unified notification script for ntfy
# Usage: ./notify.sh <topic> <title> <message> [priority]

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo "Priority levels: min, low, default, high, max (default: default)"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Validate priority level
case "$PRIORITY" in
    min|low|default|high|max)
        ;;
    *)
        echo "Invalid priority level: $PRIORITY"
        echo "Valid levels: min, low, default, high, max"
        exit 1
        ;;
esac

# Set ntfy server URL (default to ntfy.sh)
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# Send notification using curl
curl -H "Title: $TITLE" \
     -H "Priority: $PRIORITY" \
     -d "$MESSAGE" \
     "$NTFY_SERVER/$TOPIC"

# Check if curl command was successful
if [ $? -eq 0 ]; then
    echo "Notification sent successfully to topic: $TOPIC"
else
    echo "Failed to send notification"
    exit 1
fi