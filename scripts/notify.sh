#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Notification Script
# Usage: scripts/notify.sh <topic> <title> <message> [priority]
#
# Sends notifications through ntfy (primary) and Gotify (fallback/relay).
# All services should call this script for notifications.
#
# Arguments:
#   topic    - ntfy topic name (e.g. homelab-alerts, backups)
#   title    - Notification title
#   message  - Notification body
#   priority - (optional) ntfy priority: min, low, default, high, urgent
#
# Environment:
#   NTFY_SERVER   - ntfy server URL (default: https://ntfy.${DOMAIN})
#   NTFY_TOKEN    - ntfy auth token for authenticated topics
#   GOTIFY_SERVER - Gotify server URL (default: https://gotify.${DOMAIN})
#   GOTIFY_TOKEN  - Gotify app token for the default channel
#   GOTIFY_PRIORITY - Gotify priority (default: 5)
#
# Examples:
#   scripts/notify.sh homelab-test "Test" "Hello World"
#   scripts/notify.sh backups "Backup Done" "All services backed up" high
#   scripts/notify.sh alerts "Alert" "CPU high on server" urgent
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$BASE_DIR/.env"

# Source root .env if available
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# Source stack-specific .env if available
STACK_ENV="$BASE_DIR/stacks/notifications/.env"
if [[ -f "$STACK_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$STACK_ENV"
fi

# Defaults
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.${DOMAIN}}"
GOTIFY_SERVER="${GOTIFY_SERVER:-https://gotify.${DOMAIN}}"

# Priority mapping: ntfy priority name -> number
declare -A PRIORITY_MAP=(
  ["min"]=1
  ["low"]=2
  ["3"]=3
  ["default"]=3
  ["normal"]=3
  ["4"]=4
  ["high"]=4
  ["5"]=5
  ["urgent"]=5
  ["max"]=5
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[notify]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[notify]${NC} $*" >&2; }
log_error() { echo -e "${RED}[notify]${NC} $*" >&2; }

# ---- Validate arguments ----
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <topic> <title> <message> [priority]" >&2
  echo "" >&2
  echo "Arguments:" >&2
  echo "  topic    - ntfy topic name" >&2
  echo "  title    - Notification title" >&2
  echo "  message  - Notification body text" >&2
  echo "  priority - (optional) min|low|default|high|urgent" >&2
  exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Resolve priority to number
PRIORITY_NUM="${PRIORITY_MAP[$PRIORITY]:-${PRIORITY_MAP[default]}}"

# ---- Send via ntfy ----
send_ntfy() {
  local url="$NTFY_SERVER/$TOPIC"
  local args=(
    -X POST
    -H "Title: $TITLE"
    -H "Priority: $PRIORITY_NUM"
    -d "$MESSAGE"
  )

  # Add auth token if configured
  if [[ -n "${NTFY_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer $NTFY_TOKEN")
  fi

  local response
  response=$(curl -sf --connect-timeout 5 --max-time 10 "${args[@]}" "$url" 2>&1)
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    log_info "ntfy: sent to $TOPIC (priority=$PRIORITY_NUM)"
    return 0
  else
    log_error "ntfy: failed to send to $TOPIC — $response"
    return 1
  fi
}

# ---- Send via Gotify ----
send_gotify() {
  # Only send to Gotify if a token is configured
  if [[ -z "${GOTIFY_TOKEN:-}" ]]; then
    return 0
  fi

  local url="$GOTIFY_SERVER/message"
  local gotify_priority="${GOTIFY_PRIORITY:-5}"

  local response
  response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -X POST \
    -H "X-Gotify-Key: $GOTIFY_TOKEN" \
    -F "title=$TITLE" \
    -F "message=$MESSAGE" \
    -F "priority=$gotify_priority" \
    "$url" 2>&1)
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    log_info "gotify: sent (priority=$gotify_priority)"
    return 0
  else
    log_error "gotify: failed — $response"
    return 1
  fi
}

# ---- Send via Apprise ----
send_apprise() {
  local url="https://apprise.${DOMAIN}/notify"

  local response
  response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$TITLE\",\"body\":\"$MESSAGE\",\"type\":\"info\"}" \
    "$url" 2>&1)
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    log_info "apprise: sent"
    return 0
  else
    log_warn "apprise: failed or not configured — $response"
    # Apprise failure is non-fatal (may not have any services configured yet)
    return 0
  fi
}

# ---- Main ----
log_info "Sending: [$TOPIC] $TITLE — $MESSAGE"

NTFY_OK=false
GOTIFY_OK=false

if send_ntfy; then
  NTFY_OK=true
fi

if send_gotify; then
  GOTIFY_OK=true
fi

send_apprise

# At least ntfy should succeed
if [[ "$NTFY_OK" == "false" ]]; then
  log_error "Notification failed — ntfy could not send"
  exit 1
fi

log_info "Notification sent successfully"
exit 0
