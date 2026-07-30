#!/usr/bin/env bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════
# ntfy Notification Helper — Backup Status Alerts
# ════════════════════════════════════════════════════════════════
# Source this in scripts or call directly:
#   ntfy-notify.sh "Title" "Message" "priority"
# ════════════════════════════════════════════════════════════════

NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

send_ntfy() {
  local title="$1" message="$2" priority="${3:-default}" tags="${4:-backup}"

  local headers=()
  headers+=(-H "Title: ${title}")
  headers+=(-H "Priority: ${priority}")
  headers+=(-H "Tags: ${tags}")

  if [[ -n "$NTFY_TOKEN" ]]; then
    headers+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
  fi

  curl -sf -X POST "${headers[@]}" -d "$message" "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || true
}

# If called directly with args, send notification
if [[ $# -ge 2 ]]; then
  send_ntfy "$1" "$2" "${3:-default}"
fi