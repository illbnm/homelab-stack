#!/usr/bin/env bash
# scripts/notify.sh
# Unified notification dispatcher for HomeLab Stack
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority]

set -euo pipefail

TOPIC="${1:-homelab}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message body provided}"
PRIORITY="${4:-default}"

# Load environment if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${ROOT_DIR}/.env" ]; then
    # shellcheck disable=SC1091
    set -a
    source "${ROOT_DIR}/.env"
    set +a
fi

DOMAIN="${DOMAIN:-homelab.local}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Map priority names to numeric/ntfy levels
case "${PRIORITY}" in
    1|min) PRIORITY_VAL="1" ;;
    2|low) PRIORITY_VAL="2" ;;
    3|default) PRIORITY_VAL="3" ;;
    4|high) PRIORITY_VAL="4" ;;
    5|urgent|max) PRIORITY_VAL="5" ;;
    *) PRIORITY_VAL="3" ;;
esac

echo "[notify] Sending alert to ${NTFY_URL}/${TOPIC} [Priority: ${PRIORITY_VAL}]..."

HTTP_HEADER=()
if [ -n "${NTFY_TOKEN}" ]; then
    HTTP_HEADER+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
fi

HTTP_HEADER+=(
    -H "Title: ${TITLE}"
    -H "Priority: ${PRIORITY_VAL}"
    -H "Tags: bell,warning"
)

# Dispatch to ntfy
CURL_OUTPUT=$(curl -s -S -X POST "${NTFY_URL}/${TOPIC}" \
    "${HTTP_HEADER[@]}" \
    -d "${MESSAGE}")

echo "[notify] Success: Delivered message '${TITLE}' to topic '${TOPIC}'."
