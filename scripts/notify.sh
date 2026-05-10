#!/usr/bin/env bash
# =============================================================================
# notify.sh — Unified Notification Script
#
# Sends notifications via ntfy and/or Gotify.
# Works with any service that supports webhook-style notifications.
#
# Usage:
#   ./notify.sh [options] <message>
#
# Options:
#   -t, --title TITLE      Notification title (default: "HomeLab Alert")
#   -p, --priority PRIO    Priority: min/low/default/high/max (ntfy) or 1-10 (Gotify)
#   -s, --service SERVICE  Service to send to: ntfy, gotify, all (default: all)
#   -T, --topic TOPIC      ntfy topic name (default: homelab-alerts)
#   --ntfy-url URL         ntfy server URL (default: https://ntfy.$DOMAIN)
#   --gotify-url URL       Gotify server URL (default: https://gotify.$DOMAIN)
#   --gotify-token TOKEN   Gotify application token
#   -c, --config FILE      Config file with env vars
#   -q, --quiet            Suppress output
#   -h, --help             Show this help
#
# Environment variables (can be set in .env):
#   NOTIFY_NTFY_URL        ntfy server URL
#   NOTIFY_NTFY_TOPIC      ntfy default topic
#   NOTIFY_GOTIFY_URL      Gotify server URL
#   NOTIFY_GOTIFY_TOKEN    Gotify application token
#   NOTIFY_DEFAULT_TITLE   Default notification title
#
# Examples:
#   ./notify.sh "Backup completed successfully"
#   ./notify.sh -t "CRITICAL" -p high -s ntfy "Disk usage above 90%"
#   ./notify.sh --topic my-channel "Custom topic message"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# ---- Defaults ----
DEFAULT_TITLE="${NOTIFY_DEFAULT_TITLE:-HomeLab Alert}"
DEFAULT_PRIORITY="default"
DEFAULT_TOPIC="${NOTIFY_NTFY_TOPIC:-homelab-alerts}"
NTFY_DEFAULT_URL="${NOTIFY_NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
GOTIFY_DEFAULT_URL="${NOTIFY_GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}}"
GOTIFY_DEFAULT_TOKEN="${NOTIFY_GOTIFY_TOKEN:-}"
SERVICE="all"
QUIET=false

# ---- Parse Arguments ----
TITLE="$DEFAULT_TITLE"
PRIORITY="$DEFAULT_PRIORITY"
TOPIC="$DEFAULT_TOPIC"
NTFY_URL="$NTFY_DEFAULT_URL"
GOTIFY_URL="$GOTIFY_DEFAULT_URL"
GOTIFY_TOKEN="$GOTIFY_DEFAULT_TOKEN"

usage() {
  sed -n 's/^# \{0,1\}//p; /^[^#]/q' "$0" | sed '1,2d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--title) TITLE="$2"; shift 2 ;;
    -p|--priority) PRIORITY="$2"; shift 2 ;;
    -s|--service) SERVICE="$2"; shift 2 ;;
    -T|--topic) TOPIC="$2"; shift 2 ;;
    --ntfy-url) NTFY_URL="$2"; shift 2 ;;
    --gotify-url) GOTIFY_URL="$2"; shift 2 ;;
    --gotify-token) GOTIFY_TOKEN="$2"; shift 2 ;;
    -c|--config) source "$2"; shift 2 ;;
    -q|--quiet) QUIET=true; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) break ;;
  esac
done

MESSAGE="${*:-}"
if [[ -z "$MESSAGE" ]]; then
  echo "Error: No message provided" >&2
  usage
fi

# ---- ntfy ----
send_ntfy() {
  local payload
  payload=$(cat <<EOF
{
  "topic": "$TOPIC",
  "title": "$TITLE",
  "message": "$MESSAGE",
  "priority": $([ "$PRIORITY" = "min" ] && echo 1 || [ "$PRIORITY" = "low" ] && echo 2 || [ "$PRIORITY" = "default" ] && echo 3 || [ "$PRIORITY" = "high" ] && echo 4 || [ "$PRIORITY" = "max" ] && echo 5 || echo 3)
}
EOF
)
  local resp
  resp=$(curl -sf -X POST "$NTFY_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1) && {
    $QUIET || echo "ntfy: Sent to topic '$TOPIC'"
    return 0
  } || {
    echo "ntfy: Failed ($resp)" >&2
    return 1
  }
}

# ---- Gotify ----
send_gotify() {
  if [[ -z "$GOTIFY_TOKEN" ]]; then
    echo "Gotify: Skipped (no token configured)" >&2
    return 1
  fi

  local priority_int
  case "$PRIORITY" in
    min|low) priority_int=1 ;;
    default) priority_int=5 ;;
    high|max) priority_int=10 ;;
    *) priority_int=5 ;;
  esac

  local resp
  resp=$(curl -sf -X POST "${GOTIFY_URL%/}/message?token=$GOTIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"$TITLE\", \"message\": \"$MESSAGE\", \"priority\": $priority_int}" 2>&1) && {
    $QUIET || echo "Gotify: Sent successfully"
    return 0
  } || {
    echo "Gotify: Failed ($resp)" >&2
    return 1
  }
}

# ---- Main ----
EXIT_CODE=0

case "$SERVICE" in
  ntfy)
    send_ntfy || EXIT_CODE=$?
    ;;
  gotify)
    send_gotify || EXIT_CODE=$?
    ;;
  all|*)
    send_ntfy || EXIT_CODE=$?
    send_gotify || true  # Don't fail if Gotify not configured
    ;;
esac

exit $EXIT_CODE