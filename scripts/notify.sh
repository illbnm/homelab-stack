#!/usr/bin/env bash
# =============================================================================
# notify.sh — HomeLab Stack 统一通知脚本
# 所有服务通过此脚本发送通知，不直接调用 ntfy/Gotify API
#
# Usage:
#   ./notify.sh <topic> <title> <message> [priority]
#
# Priority: 1=min, 2=low, 3=default, 4=high, 5=urgent
#
# Examples:
#   ./notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 4
#   ./notify.sh homelab-updates "Watchtower" "nginx updated to 1.25"
#   ./notify.sh homelab-test "Test" "Hello World"
# =============================================================================

set -euo pipefail

# ── Args ─────────────────────────────────────────────────────────────────────
TOPIC="${1:?Usage: notify.sh <topic> <title> <message> [priority]}"
TITLE="${2:?Missing title}"
MESSAGE="${3:?Missing message}"
PRIORITY="${4:-3}"

# ── Config ───────────────────────────────────────────────────────────────────
# Load .env if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# ── Priority mapping ─────────────────────────────────────────────────────────
# ntfy uses: min(1), low(2), default(3), high(4), urgent(5)
# gotify uses: 1-10 (we map 1-5 to 2-10)
declare -A NTFY_PRIORITY=( [1]="min" [2]="low" [3]="default" [4]="high" [5]="urgent" )
NTFY_PRIO="${NTFY_PRIORITY[$PRIORITY]:-default}"
GOTIFY_PRIO=$(( (PRIORITY - 1) * 2 + 1 ))  # 1→1, 2→3, 3→5, 4→7, 5→9

# ── Functions ────────────────────────────────────────────────────────────────

send_ntfy() {
  local auth_args=()
  [[ -n "$NTFY_TOKEN" ]] && auth_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")

  curl -sf \
    "${auth_args[@]+"${auth_args[@]}"}" \
    -H "Title: ${TITLE}" \
    -H "Tags: homelab" \
    -d "${MESSAGE}" \
    "${NTFY_URL}/${TOPIC}/json" \
    -G --data-urlencode "prio=${NTFY_PRIO}" > /dev/null 2>&1
}

send_gotify() {
  [[ -z "$GOTIFY_TOKEN" ]] && return 1

  curl -sf \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"${MESSAGE}\", \"title\": \"${TITLE}\", \"priority\": ${GOTIFY_PRIO}, \"extras\": {\"tags\": [\"homelab\"]}}" \
    "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" > /dev/null 2>&1
}

log_info()  { echo "[INFO]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# ── Main ────────────────────────────────────────────────────────────────────

# Try ntfy first; on failure, fallback to Gotify
if send_ntfy; then
  log_info "Notification sent via ntfy: [${TOPIC}] ${TITLE}"
else
  log_info "ntfy failed, trying Gotify fallback..."
  if send_gotify; then
    log_info "Notification sent via Gotify: [${TOPIC}] ${TITLE}"
  else
    log_error "All notification channels failed (ntfy + Gotify)"
    exit 1
  fi
fi
