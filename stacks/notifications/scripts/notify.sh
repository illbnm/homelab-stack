#!/usr/bin/env bash
# Unified Notification Dispatcher
# Usage: notify.sh <topic> <title> <message> [priority]
set -e

TOPIC="${1:-alerts}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message provided}"
PRIORITY="${4:-default}"

NTFY_URL="${NTFY_URL:-http://localhost:8089}"

curl -s \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -d "$MESSAGE" \
  "$NTFY_URL/$TOPIC" > /dev/null

echo "[OK] Notification sent to $TOPIC"
