#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script for HomeLab Stack
# =============================================================================
# Usage: notify.sh <topic> <title> <message> [priority]
#
# Examples:
#   notify.sh homelab-alerts "Disk Space" "Root partition at 90%" high
#   notify.sh homelab-test "Test" "Hello World"
#
# This script is the single entry point for all notification needs.
# Services should call this instead of directly hitting ntfy/Gotify APIs.
# =============================================================================
set -euo pipefail

NTFY_BASE_URL="${NTFY_URL:-http://ntfy:80}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

TOPIC="${1:?Usage: notify.sh <topic> <title> <message> [priority]}"
TITLE="${2:?Usage: notify.sh <topic> <title> <message> [priority]}"
MESSAGE="${3:?Usage: notify.sh <topic> <title> <message> [priority]}"
PRIORITY="${4:-default}"

log() { echo "[notify] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }

# --- Send to ntfy ---
send_ntfy() {
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    --data-binary "${MESSAGE}" \
    "${NTFY_BASE_URL}/${TOPIC}" 2>/dev/null || echo "000")

  if [[ "$http_code" == "200" ]]; then
    log "ntfy: sent to topic '${TOPIC}' (HTTP ${http_code})"
  else
    log "ntfy: failed to send (HTTP ${http_code})"
    return 1
  fi
}

# --- Send to Gotify (backup) ---
send_gotify() {
  if [[ -z "$GOTIFY_TOKEN" ]]; then
    log "gotify: skipped (no GOTIFY_TOKEN configured)"
    return 0
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -F "title=${TITLE}" \
    -F "message=${MESSAGE}" \
    -F "priority=5" \
    "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" 2>/dev/null || echo "000")

  if [[ "$http_code" == "200" ]]; then
    log "gotify: sent successfully (HTTP ${http_code})"
  else
    log "gotify: failed to send (HTTP ${http_code})"
  fi
}

# --- Main ---
main() {
  local ntfy_ok=false

  if send_ntfy; then
    ntfy_ok=true
  fi

  # Always try Gotify as backup
  send_gotify || true

  if [[ "$ntfy_ok" == "false" ]]; then
    log "WARNING: ntfy delivery failed"
    exit 1
  fi
}

main
