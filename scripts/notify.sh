#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script
# Usage: notify.sh <topic> <title> <message> [priority]
#
# All services should call this script instead of directly calling
# ntfy/Gotify APIs. This provides a single integration point.
#
# Priority levels: 1=min, 2=low, 3=default, 4=high, 5=urgent
#
# Environment variables:
#   NTFY_URL      — ntfy server URL (default: http://ntfy:80)
#   NTFY_TOKEN    — ntfy auth token (optional)
#   GOTIFY_URL    — Gotify server URL (default: http://gotify:80)
#   GOTIFY_TOKEN  — Gotify app token (optional, enables fallback)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") <topic> <title> <message> [priority]

Arguments:
  topic       Notification topic/channel (e.g. homelab-alerts, watchtower)
  title       Notification title
  message     Notification body text
  priority    Priority level 1-5 (default: 3)
              1=min, 2=low, 3=default, 4=high, 5=urgent

Examples:
  $(basename "$0") homelab-test "Test" "Hello World"
  $(basename "$0") homelab-alerts "Disk Full" "Root partition at 95%" 5
  $(basename "$0") watchtower "Update" "Container nginx updated" 2

Environment:
  NTFY_URL      ntfy server URL (default: http://ntfy:80)
  NTFY_TOKEN    ntfy auth token (optional)
  GOTIFY_URL    Gotify server URL (default: http://gotify:80)
  GOTIFY_TOKEN  Gotify app token (optional, enables Gotify fallback)
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [ $# -lt 3 ]; then
    echo "Error: Missing required arguments." >&2
    usage
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

if ! [[ "$PRIORITY" =~ ^[1-5]$ ]]; then
    echo "Error: Priority must be between 1 and 5." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Map priority to Gotify priority (ntfy 1-5 → Gotify 0-10)
# ---------------------------------------------------------------------------
map_gotify_priority() {
    case "$1" in
        1) echo 1 ;;
        2) echo 3 ;;
        3) echo 5 ;;
        4) echo 8 ;;
        5) echo 10 ;;
        *) echo 5 ;;
    esac
}

# ---------------------------------------------------------------------------
# Send via ntfy (primary)
# ---------------------------------------------------------------------------
send_ntfy() {
    local headers=(-H "Title: ${TITLE}" -H "Priority: ${PRIORITY}")

    if [ -n "$NTFY_TOKEN" ]; then
        headers+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
    fi

    if curl -sf "${headers[@]}" -d "$MESSAGE" "${NTFY_URL}/${TOPIC}" > /dev/null 2>&1; then
        echo "[ntfy] Notification sent: ${TOPIC} — ${TITLE}"
        return 0
    else
        echo "[ntfy] Failed to send notification." >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Send via Gotify (fallback)
# ---------------------------------------------------------------------------
send_gotify() {
    if [ -z "$GOTIFY_TOKEN" ]; then
        echo "[gotify] No GOTIFY_TOKEN set, skipping fallback." >&2
        return 1
    fi

    local gotify_priority
    gotify_priority=$(map_gotify_priority "$PRIORITY")

    if curl -sf \
        -X POST "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"${TITLE}\",\"message\":\"${MESSAGE}\",\"priority\":${gotify_priority}}" \
        > /dev/null 2>&1; then
        echo "[gotify] Notification sent (fallback): ${TOPIC} — ${TITLE}"
        return 0
    else
        echo "[gotify] Fallback also failed." >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main: try ntfy first, fall back to Gotify
# ---------------------------------------------------------------------------
if send_ntfy; then
    exit 0
fi

echo "Attempting Gotify fallback..." >&2
if send_gotify; then
    exit 0
fi

echo "Error: All notification channels failed." >&2
exit 1
