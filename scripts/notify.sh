#!/bin/bash
# Unified notification script for homelab-stack
# Usage: notify.sh <topic> <title> <message> [priority] [tags]

TOPIC="${1:-homelab}"
TITLE="${2:-Notification}"
MESSAGE="${3:-}"
PRIORITY="${4:-3}"
TAGS="${5:-loudspeaker}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

if [ -z "$MESSAGE" ]; then
  echo "Usage: $0 <topic> <title> <message> [priority] [tags]"
  exit 1
fi

# Build ntfy request
curl -s -H "Title: ${TITLE}" \
     -H "Priority: ${PRIORITY}" \
     -H "Tags: ${TAGS}" \
     ${NTFY_TOKEN:+-H "Authorization: Bearer ${NTFY_TOKEN}"} \
     -d "${MESSAGE}" \
     "${NTFY_URL}/${TOPIC}" > /dev/null 2>&1

exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo "✅ Notification sent to ${TOPIC}"
else
  echo "❌ Failed to send notification (exit code: $exit_code)" >&2
fi
exit $exit_code
