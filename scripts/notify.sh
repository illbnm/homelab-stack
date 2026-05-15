#!/bin/bash
# =============================================================================
# Unified notification script
# Usage: ./notify.sh <topic> <title> <message> [priority]
# Priority: min, low, default, high, max (default: default)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOPIC="${1:-}"
TITLE="${2:-}"
MESSAGE="${3:-}"
PRIORITY="${4:-default}"

if [ -z "$TOPIC" ] || [ -z "$TITLE" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    exit 1
fi

# Source .env if available
ENV_FILE="$SCRIPT_DIR/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Try ntfy first
NTFY_URL="${DOMAIN:-localhost}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
if [ -n "$NTFY_TOKEN" ]; then
    curl -sf -u ":$NTFY_TOKEN" \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY" \
        -H "Tags: computer" \
        -d "$MESSAGE" \
        "https://ntfy.$NTFY_URL/$TOPIC" > /dev/null 2>&1 && echo "ntfy: OK" && exit 0
fi

# Fallback to Gotify
GOTIFY_URL="${GOTIFY_URL:-http://localhost}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
if [ -n "$GOTIFY_TOKEN" ]; then
    curl -sf -X POST \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":5}" \
        "$GOTIFY_URL/message" > /dev/null 2>&1 && echo "gotify: OK" && exit 0
fi

echo "notify.sh: No notification provider configured"
exit 1
