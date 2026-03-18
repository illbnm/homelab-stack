#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script — 通知统一入口
# Sends notifications via ntfy (primary) and Gotify (backup)
# =============================================================================
# Usage: scripts/notify.sh <topic> <title> <message> [priority]
# Priority: min, low, default, high, urgent
# Example: scripts/notify.sh homelab-alerts "Disk Warning" "Root disk at 90%" high
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/.env"

# Load environment
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Defaults
DOMAIN="${DOMAIN:-localhost}"
NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
DEFAULT_PRIORITY="${DEFAULT_PRIORITY:-default}"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[notify]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[notify]${NC} $*"; }
log_error() { echo -e "${RED}[notify]${NC} $*" >&2; }

usage() {
  echo "Usage: $0 <topic> <title> <message> [priority]"
  echo ""
  echo "Arguments:"
  echo "  topic     Notification topic (e.g. homelab-alerts, watchtower)"
  echo "  title     Notification title"
  echo "  message   Notification message body"
  echo "  priority  Optional: min|low|default|high|urgent (default: default)"
  echo ""
  echo "Examples:"
  echo "  $0 homelab-test \"Test\" \"Hello World\""
  echo "  $0 homelab-alerts \"Disk Warning\" \"Root disk at 90%\" high"
  exit 1
}

send_ntfy() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-$DEFAULT_PRIORITY}"

  local url="${NTFY_BASE_URL}/${topic}"
  local response
  response=$(curl -sf \
    -H "Title: ${title}" \
    -H "Priority: ${priority}" \
    -d "${message}" \
    "${url}" 2>&1) || {
    log_warn "ntfy send failed: ${response}"
    return 1
  }
  log_info "ntfy: sent to ${topic}"
  return 0
}

send_gotify() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-$DEFAULT_PRIORITY}"

  # Map ntfy priority to Gotify priority (0-10)
  local gotify_priority=5
  case "$priority" in
    min)    gotify_priority=1 ;;
    low)    gotify_priority=3 ;;
    default) gotify_priority=5 ;;
    high)   gotify_priority=8 ;;
    urgent) gotify_priority=10 ;;
  esac

  if [[ -z "$GOTIFY_TOKEN" ]]; then
    log_warn "Gotify: GOTIFY_TOKEN not set, skipping"
    return 1
  fi

  local url="${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}"
  local response
  response=$(curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"${title}\",\"message\":\"${message}\",\"priority\":${gotify_priority}}" \
    "${url}" 2>&1) || {
    log_warn "Gotify send failed: ${response}"
    return 1
  }
  log_info "Gotify: sent notification"
  return 0
}

# --- Main ---
[[ $# -lt 3 ]] && usage

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-$DEFAULT_PRIORITY}"

# Validate priority
case "$PRIORITY" in
  min|low|default|high|urgent) ;;
  *) log_error "Invalid priority: ${PRIORITY}. Use: min|low|default|high|urgent"; exit 1 ;;
esac

SENT=0

# Send via ntfy (primary)
if send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY"; then
  SENT=$((SENT + 1))
fi

# Send via Gotify (backup)
if send_gotify "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY"; then
  SENT=$((SENT + 1))
fi

if [[ $SENT -eq 0 ]]; then
  log_error "All notification channels failed!"
  exit 1
fi

log_info "Notification delivered (${SENT}/2 channels)"
exit 0
