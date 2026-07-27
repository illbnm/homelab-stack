#!/usr/bin/env bash
# scripts/notify.sh - Unified Notification CLI for Homelab Stack
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority]

set -euo pipefail

TOPIC="${1:-homelab-alerts}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message body provided}"
PRIORITY="${4:-3}"

# Load environment variables if .env exists
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

DOMAIN="${DOMAIN:-homelab.local}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"

echo "[Notify] Sending message to topic '${TOPIC}' at ${NTFY_URL}..."

curl -s -X POST "${NTFY_URL}/${TOPIC}" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -d "${MESSAGE}"

echo ""
echo "[Notify] Notification dispatched successfully."
