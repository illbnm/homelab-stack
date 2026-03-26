#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script — ntfy + Gotify
# Usage: ./notify.sh <topic> <title> <message> [priority] [backend]
#
# Backends: ntfy (default), gotify
# Priority:  1=min, 2=low, 3=normal, 4=high, 5=urgent
#
# Examples:
#   ./notify.sh homelab-test "Hello" "World"
#   ./notify.sh homelab-alerts "Critical" "Disk full" 5
#   ./notify.sh homelab-backup "Done" "Backup complete" 3 gotify
# =============================================================================

set -euo pipefail

# --- Config ---
NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-localhost}}"
GOTIFY_BASE_URL="${GOTIFY_BASE_URL:-https://gotify.${DOMAIN:-localhost}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-changeme}"

# --- Args ---
TOPIC="${1:-}"
TITLE="${2:-}"
MESSAGE="${3:-}"
PRIORITY="${4:-3}"
BACKEND="${5:-ntfy}"

if [[ -z "$TOPIC" || -z "$TITLE" || -z "$MESSAGE" ]]; then
  echo "Usage: $0 <topic> <title> <message> [priority] [backend]"
  echo "  priority: 1=min, 2=low, 3=normal, 4=high, 5=urgent  (default: 3)"
  echo "  backend:  ntfy, gotify  (default: ntfy)"
  exit 1
fi

# Map priority name to ntfy integer
NTFY_PRIORITY="$PRIORITY"

send_ntfy() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-3}"

  curl -s \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: bell,robot" \
    -d "$message" \
    "${NTFY_BASE_URL}/${topic}"
}

send_gotify() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-3}"

  # Gotify priority: 0-10 (scale up from ntfy's 1-5)
  local gotify_priority=$((priority * 2))
  [[ $gotify_priority -gt 10 ]] && gotify_priority=10

  curl -s -X POST \
    "${GOTIFY_BASE_URL}/message?token=${GOTIFY_TOKEN}" \
    -F "title=$title" \
    -F "message=$message" \
    -F "priority=$gotify_priority" \
    -F "tags=bell"
}

case "$BACKEND" in
  ntfy)
    send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$NTFY_PRIORITY"
    ;;
  gotify)
    send_gotify "$TOPIC" "$TITLE" "$MESSAGE" "$NTFY_PRIORITY"
    ;;
  *)
    echo "Unknown backend: $BACKEND" >&2
    exit 1
    ;;
esac
