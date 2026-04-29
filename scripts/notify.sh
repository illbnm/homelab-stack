#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
NTFY_URL="${NTFY_URL:-https://ntfy.example.com}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.example.com}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
BACKEND="${NOTIFY_BACKEND:-ntfy}"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <topic> <title> <message> [priority]

Unified notification script for the homelab stack.
All other scripts should call this interface instead of ntfy/Gotify directly.

Arguments:
  topic     Notification topic/channel (e.g. homelab-alerts, updates)
  title     Notification title
  message   Notification body
  priority  (optional) 1-5 for ntfy, or low/normal/high for Gotify (default: default)

Environment variables:
  NTFY_URL        ntfy server URL (default: https://ntfy.example.com)
  GOTIFY_URL      Gotify server URL (default: https://gotify.example.com)
  GOTIFY_TOKEN    Gotify app token (required for Gotify backend)
  NOTIFY_BACKEND  ntfy or gotify (default: ntfy)

Examples:
  $SCRIPT_NAME homelab-alerts "Disk Warning" "/dev/sda1 is 85% full" high
  $SCRIPT_NAME updates "Watchtower" "Container nginx updated to 1.25" default
  NOTIFY_BACKEND=gotify $SCRIPT_NAME my-app "Build Done" "Image pushed" 5
EOF
    exit "${1:-0}"
}

send_ntfy() {
    local topic="$1" title="$2" message="$3" priority="${4:-default}"
    curl -sS -f \
        -H "Title: ${title}" \
        -H "Priority: ${priority}" \
        -d "${message}" \
        "${NTFY_URL}/${topic}"
}

send_gotify() {
    local topic="$1" title="$2" message="$3" priority="${4:-5}"
    if [[ -z "${GOTIFY_TOKEN}" ]]; then
        echo "ERROR: GOTIFY_TOKEN is required for Gotify backend" >&2
        return 1
    fi
    local gotify_priority
    case "${priority}" in
        low|1)      gotify_priority=1 ;;
        default|2|3) gotify_priority=5 ;;
        high|4|5)   gotify_priority=8 ;;
        *)          gotify_priority=5 ;;
    esac
    curl -sS -f \
        -X POST \
        -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"${title}\",\"message\":\"${message}\",\"priority\":${gotify_priority}}" \
        "${GOTIFY_URL}/message"
}

if [[ $# -lt 3 ]]; then
    usage 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

case "${BACKEND}" in
    ntfy)   send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY" ;;
    gotify) send_gotify "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY" ;;
    *)
        echo "ERROR: Unknown NOTIFY_BACKEND '${BACKEND}'. Use 'ntfy' or 'gotify'." >&2
        exit 1
        ;;
esac