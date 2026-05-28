#!/bin/bash

# Unified notification script for ntfy
# Usage: ./notify.sh <topic> <title> <message> [priority]

if [ $# -lt 3 ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo "Example: $0 homelab-test \"Test\" \"Hello World\" 3"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"  # Default priority 3 (normal)

# Send notification to ntfy
curl -H "Title: $TITLE" \
     -H "Priority: $PRIORITY" \
     -d "$MESSAGE" "https://ntfy.${DOMAIN}/$TOPIC"