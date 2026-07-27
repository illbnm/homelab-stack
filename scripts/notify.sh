#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script for HomeLab Stack
# Supports sending notifications via ntfy and Gotify
# Usage:
#   notify.sh <topic> <title> <message> [priority]
# =============================================================================
set -euo pipefail

# Configuration: URLs and tokens for ntfy and Gotify
NTFY_URL="http://localhost:2586"          # ntfy server URL
GOTIFY_URL="http://localhost:8080"        # Gotify server URL
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"           # Gotify API token (set in environment)

usage() {
  echo "Usage: $0 <topic> <title> <message> [priority]"
  echo "  topic    - Notification topic (ntfy topic)"
  echo "  title    - Notification title"
  echo "  message  - Notification message body"
  echo "  priority - Optional priority (ntfy: -2 to 5, default 0)"
  exit 1
}

if [[ $# -lt 3 ]]; then
  usage
fi

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-0}

# Validate priority is integer between -2 and 5 for ntfy
if ! [[ "$PRIORITY" =~ ^-?[0-9]+$ ]] || (( PRIORITY < -2 )) || (( PRIORITY > 5 )); then
  echo "Priority must be an integer between -2 and 5"
  exit 1
fi

# Send notification via ntfy
send_ntfy() {
  curl -sS -X POST \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -d "$MESSAGE" \
    "$NTFY_URL/$TOPIC" || echo "Failed to send ntfy notification"
}

# Send notification via Gotify
send_gotify() {
  if [[ -z "$GOTIFY_TOKEN" ]]; then
    echo "Gotify token not set, skipping Gotify notification"
    return
  fi
  curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "X-Gotify-Key: $GOTIFY_TOKEN" \
    -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$PRIORITY}" \
    "$GOTIFY_URL/message" || echo "Failed to send Gotify notification"
}

send_ntfy
send_gotify
