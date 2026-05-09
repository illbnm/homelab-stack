#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Notification Script
# Sends notifications via ntfy (primary) with Gotify fallback.
#
# Usage:
#   notify.sh <topic> <title> <message> [priority] [tags]
#
# Arguments:
#   topic    — ntfy topic name (e.g., homelab-alerts, homelab-info)
#   title    — Notification title
#   message  — Notification body
#   priority — min|low|default|high|urgent (default: default)
#   tags     — Comma-separated emoji tags (e.g., warning,rotating_light)
#
# Examples:
#   notify.sh homelab-alerts "Disk Full" "/data at 92%" urgent warning
#   notify.sh homelab-info "Backup Complete" "All stacks backed up" default white_check_mark
#   notify.sh test "Test" "Hello World"
#
# Environment:
#   NTFY_URL    — ntfy server URL (default: https://ntfy.${DOMAIN})
#   NTFY_TOKEN  — ntfy access token (if auth enabled)
#   GOTIFY_URL  — Gotify server URL (fallback)
#   GOTIFY_TOKEN— Gotify app token (fallback)
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# ── Config ───────────────────────────────────────────────────────────────────
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# ── Arguments ────────────────────────────────────────────────────────────────
TOPIC="${1:-}"
TITLE="${2:-}"
MESSAGE="${3:-}"
PRIORITY="${4:-default}"
TAGS="${5:-}"

if [ -z "$TOPIC" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: notify.sh <topic> <title> <message> [priority] [tags]"
  echo ""
  echo "Examples:"
  echo "  notify.sh homelab-alerts \"CPU High\" \"95% usage\" urgent warning"
  echo "  notify.sh homelab-info \"Update\" \"Containers updated\" default rocket"
  exit 1
fi

# ── Send via ntfy ────────────────────────────────────────────────────────────
send_ntfy() {
  local auth_header=""
  if [ -n "$NTFY_TOKEN" ]; then
    auth_header="-H Authorization: Bearer $NTFY_TOKEN"
  fi

  local tags_header=""
  if [ -n "$TAGS" ]; then
    tags_header="-H Tags: $TAGS"
  fi

  curl -sf ${auth_header} \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    ${tags_header} \
    -d "$MESSAGE" \
    "$NTFY_URL/$TOPIC" > /dev/null 2>&1
}

send_gotify() {
  if [ -z "$GOTIFY_TOKEN" ]; then
    return 1
  fi

  curl -sf \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$( \
      case $PRIORITY in urgent|max) echo 10;; high) echo 8;; default) echo 5;; low) echo 3;; min) echo 1;; *) echo 5;; esac \
    )}" \
    "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" > /dev/null 2>&1
}

# ── Main ─────────────────────────────────────────────────────────────────────
if send_ntfy; then
  echo "[OK] Notification sent via ntfy: $TOPIC"
else
  echo "[WARN] ntfy failed, trying Gotify fallback..." >&2
  if send_gotify; then
    echo "[OK] Notification sent via Gotify"
  else
    echo "[ERROR] All notification channels failed!" >&2
    exit 1
  fi
fi
