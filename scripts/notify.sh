#!/usr/bin/env bash
# notify.sh — Send notifications via ntfy, Gotify, or Apprise
# Usage:
#   ./scripts/notify.sh --service ntfy    --topic alerts --title "Test" --message "Hello"
#   ./scripts/notify.sh --service gotify  --title "Test" --message "Hello"
#   ./scripts/notify.sh --service apprise --title "Test" --message "Hello"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

SERVICE=""
TOPIC=""
TITLE="Homelab Notification"
MESSAGE=""
NTFY_URL="https://ntfy.${DOMAIN:-localhost}"
GOTIFY_URL="https://gotify.${DOMAIN:-localhost}"
APPRISE_URL="https://apprise.${DOMAIN:-localhost}"

usage() {
    echo "Usage: $0 --service <ntfy|gotify|apprise> [--topic TOPIC] --title TITLE --message MESSAGE"
    echo ""
    echo "Options:"
    echo "  --service   Notification service: ntfy, gotify, or apprise"
    echo "  --topic     Topic (ntfy only, default: 'homelab')"
    echo "  --title     Notification title"
    echo "  --message   Notification body"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --service)  SERVICE="$2"; shift 2 ;;
        --topic)    TOPIC="$2"; shift 2 ;;
        --title)    TITLE="$2"; shift 2 ;;
        --message)  MESSAGE="$2"; shift 2 ;;
        -h|--help)  usage ;;
        *)          echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$SERVICE" ]] && { echo "Error: --service is required"; usage; }
[[ -z "$MESSAGE" ]] && { echo "Error: --message is required"; usage; }

send_ntfy() {
    local topic="${TOPIC:-homelab}"
    curl -s -X POST "${NTFY_URL}/${topic}" \
        -H "Title: ${TITLE}" \
        -H "Priority: default" \
        -d "${MESSAGE}" || echo "Warning: ntfy send failed (is the stack running?)"
}

send_gotify() {
    local token="${GOTIFY_TOKEN:-}"
    if [[ -z "$token" ]]; then
        echo "Error: GOTIFY_TOKEN not set. Get it from https://gotify.${DOMAIN:-localhost}"
        exit 1
    fi
    curl -s -X POST "${GOTIFY_URL}/message" \
        -H "X-Gotify-Key: ${token}" \
        -d "title=${TITLE}" \
        -d "message=${MESSAGE}" \
        -d "priority=5" || echo "Warning: Gotify send failed"
}

send_apprise() {
    curl -s -X POST "${APPRISE_URL}/notify" \
        -d "title=${TITLE}" \
        -d "body=${MESSAGE}" || echo "Warning: Apprise send failed"
}

case "$SERVICE" in
    ntfy)    send_ntfy ;;
    gotify)  send_gotify ;;
    apprise) send_apprise ;;
    *)       echo "Unknown service: $SERVICE. Use: ntfy, gotify, apprise"; exit 1 ;;
esac
