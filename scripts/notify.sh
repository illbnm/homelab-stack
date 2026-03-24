#!/usr/bin/env bash
# =============================================================================
# notify.sh — Unified notification dispatcher
# Sends messages to both ntfy and Gotify
#
# Usage:
#   ./notify.sh [-t title] [-p priority] [-s ntfy|gotify|both] <message>
#
# Environment variables (from .env):
#   NTFY_TOPIC        — ntfy topic name (default: homelab)
#   NTFY_BASE_URL     — ntfy server URL (default: https://ntfy.${DOMAIN})
#   NTFY_TOKEN        — ntfy auth token (optional)
#   GOTIFY_TOKEN      — Gotify application token
#   GOTIFY_BASE_URL   — Gotify server URL (default: https://gotify.${DOMAIN})
#   DOMAIN            — base domain for defaults
# =============================================================================
set -euo pipefail

# --- Defaults ---
TITLE="HomeLab Alert"
PRIORITY="default"
SEND_TO="both"
NTFY_TOPIC="${NTFY_TOPIC:-homelab}"
NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-example.com}}"
GOTIFY_BASE_URL="${GOTIFY_BASE_URL:-https://gotify.${DOMAIN:-example.com}}"

# --- Parse args ---
while getopts "t:p:s:" opt; do
  case "$opt" in
    t) TITLE="$OPTARG" ;;
    p) PRIORITY="$OPTARG" ;;
    s) SEND_TO="$OPTARG" ;;
    *) echo "Usage: $0 [-t title] [-p priority] [-s ntfy|gotify|both] <message>" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

MESSAGE="$*"
if [[ -z "$MESSAGE" ]]; then
  echo "Error: no message provided" >&2
  echo "Usage: $0 [-t title] [-p priority] [-s ntfy|gotify|both] <message>" >&2
  exit 1
fi

# --- Send to ntfy ---
send_ntfy() {
  if [[ -z "$NTFY_TOKEN" ]]; then
    echo "[notify] warning: NTFY_TOKEN not set, sending without auth" >&2
    curl -sf -o /dev/null \
      -H "Title: ${TITLE}" \
      -H "Priority: ${PRIORITY}" \
      -d "${MESSAGE}" \
      "${NTFY_BASE_URL}/${NTFY_TOPIC}" || echo "[notify] ntfy send failed" >&2
  else
    curl -sf -o /dev/null \
      -H "Authorization: Bearer ${NTFY_TOKEN}" \
      -H "Title: ${TITLE}" \
      -H "Priority: ${PRIORITY}" \
      -d "${MESSAGE}" \
      "${NTFY_BASE_URL}/${NTFY_TOPIC}" || echo "[notify] ntfy send failed" >&2
  fi
}

# --- Send to Gotify ---
send_gotify() {
  if [[ -z "$GOTIFY_TOKEN" ]]; then
    echo "[notify] error: GOTIFY_TOKEN not set" >&2
    return 1
  fi
  curl -sf -o /dev/null \
    -X POST \
    -F "title=${TITLE}" \
    -F "message=${MESSAGE}" \
    -F "priority=$( [[ "$PRIORITY" == 'high' || "$PRIORITY" == 'urgent' || "$PRIORITY" == 'max' ]] && echo 10 || echo 5 )" \
    "${GOTIFY_BASE_URL}/message?token=${GOTIFY_TOKEN}" || echo "[notify] gotify send failed" >&2
}

# --- Dispatch ---
case "$SEND_TO" in
  ntfy)  send_ntfy ;;
  gotify) send_gotify ;;
  both)  send_ntfy; send_gotify ;;
  *)     echo "Error: unknown target '$SEND_TO' (use ntfy|gotify|both)" >&2; exit 1 ;;
esac

echo "[notify] sent: ${TITLE} → ${SEND_TO}"
