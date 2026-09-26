#!/usr/bin/env bash
set -euo pipefail

# ====================================================================
# Homelab Notification Dispatcher
# Unified alerting script for ntfy and Gotify
# Usage: scripts/notify.sh <topic> <title> <message> [priority]
# ====================================================================

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <topic> <title> <message> [priority]" >&2
  exit 1
fi

TOPIC="${1}"
TITLE="${2}"
MESSAGE="${3}"
PRIORITY="${4:-default}"

NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-localhost}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}/message}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

case "${PRIORITY,,}" in
  min|low|1)
    NTFY_PRIORITY="1"
    GOTIFY_PRIORITY="1"
    ;;
  high|urgent|critical|4|5)
    NTFY_PRIORITY="4"
    GOTIFY_PRIORITY="8"
    ;;
  *)
    NTFY_PRIORITY="3"
    GOTIFY_PRIORITY="5"
    ;;
esac

# 1. Send via ntfy
NTFY_ENDPOINT="${NTFY_BASE_URL%/}/${TOPIC}"
AUTH_HEADER=()
if [[ -n "${NTFY_TOKEN}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${NTFY_TOKEN}")
fi

curl -fsS -X POST "${NTFY_ENDPOINT}" \
  -H "Title: ${TITLE}" \
  -H "Priority: ${NTFY_PRIORITY}" \
  "${AUTH_HEADER[@]}" \
  -d "${MESSAGE}" >/dev/null || echo "[WARN] Failed to deliver alert to ntfy" >&2

# 2. Optional fallback/mirror to Gotify
if [[ -n "${GOTIFY_TOKEN}" ]]; then
  curl -fsS -X POST "${GOTIFY_URL}" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -F "title=${TITLE} [${TOPIC}]" \
    -F "message=${MESSAGE}" \
    -F "priority=${GOTIFY_PRIORITY}" >/dev/null || echo "[WARN] Failed to deliver alert to Gotify" >&2
fi
