#!/usr/bin/env bash
# Unified notification script
# Usage: notify.sh <topic> <title> <message> [priority]
# Priority: 1=min, 2=low, 3=default, 4=high, 5=urgent

set -euo pipefail

TOPIC="${1:?Usage: notify.sh <topic> <title> <message> [priority]}"
TITLE="${2:?Usage: notify.sh <topic> <title> <message> [priority]}"
MESSAGE="${3:?Usage: notify.sh <topic> <title> <message> [priority]}"
PRIORITY="${4:-3}"

# Load domain from env or .env file
if [ -z "${DOMAIN:-}" ]; then
  ENV_FILE="$(dirname "$0")/../.env"
  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
fi

NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

HEADERS=(-H "Title: ${TITLE}" -H "Priority: ${PRIORITY}")
if [ -n "$NTFY_TOKEN" ]; then
  HEADERS+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
fi

curl -sf "${HEADERS[@]}" -d "${MESSAGE}" "${NTFY_URL}/${TOPIC}"

echo "✓ Notification sent to ${TOPIC}: ${TITLE}"
