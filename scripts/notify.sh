#!/usr/bin/env bash
# notify.sh — unified notification sender
# Usage: notify.sh <topic> <title> <message> [priority]
# Priority: min, low, default, high, urgent

set -euo pipefail

TOPIC="${1:?Usage: notify.sh <topic> <title> <message> [priority]}"
TITLE="${2:?Title required}"
MESSAGE="${3:?Message required}"
PRIORITY="${4:-default}"

NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-example.com}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Build curl command
CURL_ARGS=(
  -s
  -o /dev/null
  -w "%{http_code}"
  -X POST
  "${NTFY_URL}/${TOPIC}"
  -H "Title: ${TITLE}"
  -H "Priority: ${PRIORITY}"
  -H "Content-Type: text/plain"
  -d "${MESSAGE}"
)

if [[ -n "${NTFY_TOKEN}" ]]; then
  CURL_ARGS+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
fi

STATUS=$(curl "${CURL_ARGS[@]}")

if [[ "${STATUS}" == "200" ]]; then
  echo "[OK] Notification sent to ${TOPIC} (${STATUS})"
else
  # Fallback to Gotify
  GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
  GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
  if [[ -n "${GOTIFY_TOKEN}" ]]; then
    curl -s -X POST "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
      -F "title=${TITLE}" \
      -F "message=${MESSAGE}" \
      -F "priority=5" > /dev/null
    echo "[FALLBACK] Sent via Gotify"
  else
    echo "[WARN] ntfy returned ${STATUS} and no Gotify token configured" >&2
    exit 1
  fi
fi
