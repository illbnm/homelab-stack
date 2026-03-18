#!/bin/bash

# scripts/notify.sh <topic> <title> <message> [priority]
# Default priority: 3 (default)
# Requires NTFY_URL and optionally NTFY_TOKEN in .env

TOPIC=${1:-homelab-alerts}
TITLE=${2:-"Notification"}
MESSAGE=${3:-"Test message"}
PRIORITY=${4:-3}

# Source environment variables if exist
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

DOMAIN=${DOMAIN:-localhost}
NTFY_URL=${NTFY_URL:-"https://ntfy.${DOMAIN}"}

echo "Sending notification to ${NTFY_URL}/${TOPIC}..."

curl \
  -H "Title: ${TITLE}" \
  -H "Priority: ${PRIORITY}" \
  -d "${MESSAGE}" \
  "${NTFY_URL}/${TOPIC}"
