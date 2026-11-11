#!/usr/bin/env bash
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority]
# Unified notification router supporting ntfy (primary) with Gotify fallback.
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <topic> <title> <message> [priority]" >&2
  exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"
NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-lab.example.com}}"

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  echo "[DRY-RUN] topic=${TOPIC} title=${TITLE} priority=${PRIORITY} message=${MESSAGE}"
  exit 0
fi

if curl -fsS \
  -H "Title: ${TITLE}" \
  -H "Priority: ${PRIORITY}" \
  ${NTFY_TOKEN:+-H "Authorization: Bearer ${NTFY_TOKEN}"} \
  -d "${MESSAGE}" \
  "${NTFY_BASE_URL}/${TOPIC}" >/dev/null 2>&1; then
  echo "[OK] Sent notification to ${NTFY_BASE_URL}/${TOPIC}"
  exit 0
fi

if [[ -n "${GOTIFY_URL:-}" && -n "${GOTIFY_TOKEN:-}" ]]; then
  curl -fsS "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
    -F "title=${TITLE}" \
    -F "message=${MESSAGE}" \
    -F "priority=5" >/dev/null
  echo "[OK] Sent fallback notification via Gotify"
  exit 0
fi

echo "[ERROR] Failed to deliver notification" >&2
exit 1
