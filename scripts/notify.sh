#!/usr/bin/env bash
# =============================================================================
# notify.sh — Unified notification sender for HomeLab Stack
# Usage: ./notify.sh <topic> <title> <message> [priority]
# Priority: 1=min, 3=default, 5=max/urgent
# =============================================================================

set -euo pipefail

# --- Configuration ---
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
NTFY_USER="${NTFY_USER:-admin}"
NTFY_PASSWORD="${NTFY_PASSWORD:-}"

# --- Input validation ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <topic> <title> <message> [priority]"
  echo "  topic    — ntfy topic name"
  echo "  title    — notification title"
  echo "  message  — notification body"
  echo "  priority — 1(min) to 5(max), default: 3"
  exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

# --- Build curl args ---
CURL_ARGS=(
  -sf
  --max-time 10
  -H "Title: ${TITLE}"
  -H "Priority: ${PRIORITY}"
  -d "${MESSAGE}"
)

# Add auth if password is set
if [ -n "${NTFY_PASSWORD}" ]; then
  CURL_ARGS+=(-u "${NTFY_USER}:${NTFY_PASSWORD}")
fi

# --- Send ---
URL="${NTFY_URL}/${TOPIC}"

if curl "${CURL_ARGS[@]}" "${URL}" > /dev/null 2>&1; then
  echo "[notify] Sent to ${TOPIC}: ${TITLE}"
else
  echo "[notify] ERROR: Failed to send to ${TOPIC}" >&2
  exit 1
fi
