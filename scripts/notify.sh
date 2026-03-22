#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script
# Sends messages to ntfy (and optionally gotify) using centralized config.
#
# Usage: notify.sh <topic> <title> <message> [priority]
#   priority: low, default, high (optional, default: default)
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

: "${DOMAIN:?DOMAIN not set}"

TOPIC="${1:?Topic required}"
TITLE="${2:?Title required}"
MESSAGE="${3:?Message required}"
PRIORITY="${4:-default}"

# Send to ntfy
NTFY_URL="https://ntfy.${DOMAIN}/${TOPIC}"
curl -H "Title: ${TITLE}" -H "Priority: ${PRIORITY}" -d "${MESSAGE}" "${NTFY_URL}" >/dev/null 2>&1 || echo "Warning: ntfy notification failed" >&2

# Optionally also send to gotify (uncomment to enable)
# GOTIFY_URL="https://gotify.${DOMAIN}/message?token=${GOTIFY_APP_TOKEN}"
# curl -H "X-Gotify-Title: ${TITLE}" -H "X-Gotify-Priority: $(case ${PRIORITY} in low) echo 0;; default) echo 5;; high) echo 10;; esac)" -d "${MESSAGE}" "${GOTIFY_URL}" >/dev/null 2>&1 || echo "Warning: gotify notification failed" >&2

exit 0
