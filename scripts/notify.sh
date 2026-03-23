#!/usr/bin/env bash
#
# notify.sh - Send notifications via ntfy
#
# Usage:
#   notify.sh <topic> <title> <message> [priority]
#
# Examples:
#   notify.sh homelab-test "Test" "Hello World" 3
#   notify.sh alerts "Disk Full" "Server disk usage above 90%" 4
#
# Priority levels:
#   1 = min (very low)
#   2 = low
#   3 = normal (default)
#   4 = high
#   5 = urgent (max)
#

set -euo pipefail

NTFY_HOST="${NTFY_HOST:-ntfy}"
NTFY_PORT="${NTFY_PORT:-80}"

usage() {
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo "  topic    - ntfy topic name"
    echo "  title    - notification title"
    echo "  message  - notification body"
    echo "  priority - 1-5 (optional, default: 3)"
    exit 1
}

TOPIC="${1:-}"
TITLE="${2:-}"
MESSAGE="${3:-}"
PRIORITY="${4:-3}"

[[ -z "$TOPIC" ]] || [[ -z "$TITLE" ]] || [[ -z "$MESSAGE" ]] && usage

URL="http://${NTFY_HOST}:${NTFY_PORT}/${TOPIC}"

PAYLOAD="{\"topic\": \"${TOPIC}\", \"title\": \"${TITLE}\", \"message\": \"${MESSAGE}\", \"priority\": ${PRIORITY}}"

curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null

echo "Notification sent to ${TOPIC}: ${TITLE}"
