#!/usr/bin/env bash
# notify.sh - Unified notification interface for homelab-stack
# Usage: ./notify.sh <topic> <title> <message> [priority]
# Priority: min=1, low=2, default=3, high=4, max=5

set -euo pipefail

TOPIC="${1:-homelab-default}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message}"
PRIORITY="${4:-3}"

# Load .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/.env"
fi

DOMAIN="${DOMAIN:-localhost}"
NTFY_URL="http://ntfy:80"

# Send via ntfy
send_ntfy() {
    local topic="$1" title="$2" message="$3" priority="$4"
    curl -sf -X POST "$NTFY_URL/$topic" \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: warning,server" \
        -d "$message" || echo "⚠️ ntfy send failed"
}

# Send via gotify
send_gotify() {
    local title="$1" message="$2" priority="$3"
    local gotify_url="http://gotify:8080/message"
    local gotify_token="${GOTIFY_APP_TOKEN:-}"
    if [ -z "$gotify_token" ]; then
        echo "⚠️ GOTIFY_APP_TOKEN not set, skipping gotify"
        return 1
    fi
    curl -sf -X POST "$gotify_url" \
        -H "X-Gotify-Key: $gotify_token" \
        -F "title=$title" \
        -F "message=$message" \
        -F "priority=$priority" || echo "⚠️ gotify send failed"
}

# Main
echo "📢 Sending notification: [$TITLE] $MESSAGE"
send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY"
send_gotify "$TITLE" "$MESSAGE" "$PRIORITY"
echo "✅ Notification sent"
