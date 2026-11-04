#!/usr/bin/env bash
# ==============================================================================
# Unified Notification Dispatcher for HomeLab Stack
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority] [tags]
# Priority levels (ntfy): 1 (min), 2 (low), 3 (default), 4 (high), 5 (urgent)
# ==============================================================================

set -euo pipefail

# Load environment variables if .env exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

TOPIC="${1:-homelab-alerts}"
TITLE="${2:-HomeLab Notification}"
MESSAGE="${3:-Notification from homelab-stack}"
PRIORITY="${4:-3}"
TAGS="${5:-information_source}"

DOMAIN="${DOMAIN:-homelab.local}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Check which notification service is accessible
send_ntfy() {
  local auth_header=()
  if [ -n "${NTFY_TOKEN}" ]; then
    auth_header=(-H "Authorization: Bearer ${NTFY_TOKEN}")
  fi

  curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${NTFY_URL}/${TOPIC}" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: ${TAGS}" \
    "${auth_header[@]}" \
    -d "${MESSAGE}"
}

send_gotify() {
  if [ -z "${GOTIFY_TOKEN}" ]; then
    return 1
  fi

  curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${GOTIFY_URL}/message" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"${TITLE}\", \"message\": \"${MESSAGE}\", \"priority\": ${PRIORITY}}"
}

echo "[*] Dispatching notification to topic '${TOPIC}'..."
STATUS=$(send_ntfy || echo "000")

if [ "${STATUS}" -ge 200 ] && [ "${STATUS}" -lt 300 ]; then
  echo "[+] Successfully delivered via ntfy (HTTP ${STATUS})"
  exit 0
else
  echo "[!] ntfy delivery returned HTTP ${STATUS}. Attempting Gotify fallback..."
  GOTIFY_STATUS=$(send_gotify || echo "000")
  if [ "${GOTIFY_STATUS}" -ge 200 ] && [ "${GOTIFY_STATUS}" -lt 300 ]; then
    echo "[+] Successfully delivered via Gotify fallback (HTTP ${GOTIFY_STATUS})"
    exit 0
  else
    echo "[-] Failed to dispatch notification. (ntfy: ${STATUS}, Gotify: ${GOTIFY_STATUS})"
    exit 1
  fi
fi
