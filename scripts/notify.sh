#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Notification Script
# Sends push notifications via ntfy. All other scripts should call this
# instead of directly calling ntfy/Gotify APIs.
#
# Usage:
#   ./scripts/notify.sh <topic> <title> <message> [priority] [tags]
#
# Examples:
#   ./scripts/notify.sh homelab-alerts "Disk Full" "/data is 95% full" 5 warning
#   ./scripts/notify.sh backup-status "Backup OK" "Daily backup completed" 3 check
#   ./scripts/notify.sh test "Hello" "This is a test message"
#
# Priority: 1=min, 2=low, 3=default, 4=high, 5=urgent
# Tags: comma-separated emoji names (warning, check, skull, rotating_light, etc.)
# =============================================================================

set -euo pipefail

# Load .env
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

TOPIC="${1:-}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No message}"
PRIORITY="${4:-3}"
TAGS="${5:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'

if [ -z "$TOPIC" ]; then
  echo -e "${RED}Usage: $0 <topic> <title> <message> [priority] [tags]${RESET}"
  echo "Example: $0 homelab-alerts 'Disk Full' '/data at 95%' 5 warning"
  exit 1
fi

NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Build the curl command
CURL_ARGS=(-s -o /dev/null -w "%{http_code}")
CURL_ARGS+=(-H "Title: $TITLE")
CURL_ARGS+=(-H "Priority: $PRIORITY")
CURL_ARGS+=(-H "Tags: $TAGS")
[ -n "$NTFY_TOKEN" ] && CURL_ARGS+=(-H "Authorization: Bearer $NTFY_TOKEN")
CURL_ARGS+=(-d "$MESSAGE")

HTTP_CODE=$(curl "${CURL_ARGS[@]}" "$NTFY_URL/$TOPIC" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}[OK]${RESET} Notification sent to $TOPIC: $TITLE"
else
  echo -e "${RED}[FAIL]${RESET} HTTP $HTTP_CODE — could not send to $NTFY_URL/$TOPIC"
  exit 1
fi