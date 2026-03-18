#!/usr/bin/env bash
# =============================================================================
# notify.sh — HomeLab Stack 统一通知脚本
# 所有服务通过此脚本发送通知，不直接调用 ntfy/Gotify API
#
# Usage:
#   ./scripts/notify.sh <topic> <title> <message> [priority]
#
# Priority: 1=min, 2=low, 3=default, 4=high, 5=urgent
#
# Examples:
#   ./scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 4
#   ./scripts/notify.sh homelab-updates "Watchtower" "nginx updated to 1.25"
#   ./scripts/notify.sh homelab-test "Test" "Hello World"
# =============================================================================

set -euo pipefail

# ── Args ─────────────────────────────────────────────────────────────────────
TOPIC="${1:?Usage: notify.sh <topic> <title> <message> [priority]}"
TITLE="${2:?Missing title}"
MESSAGE="${3:?Missing message}"
PRIORITY="${4:-3}"

# ── Config ───────────────────────────────────────────────────────────────────
# Load .env if available (for DOMAIN, NTFY_TOKEN, GOTIFY_TOKEN)
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

# ── Functions ────────────────────────────────────────────────────────────────

send_ntfy() {
  local auth_header=""
  if [[ -n "$NTFY_TOKEN" ]]; then
    auth_header="-H \"Authorization: Bearer ${NTFY_TOKEN}\""
  fi

  eval curl -sf \
    -H "\"Title: ${TITLE}\"" \
    -H "\"Priority: ${PRIORITY}\"" \
    -H "\"Tags: homelab\"" \
    ${auth_header} \
    -d "\"${MESSAGE}\"" \
    "\"${NTFY_URL}/${TOPIC}\"" >/dev/null 2>&1
}

send_gotify() {
  if [[ -z "$GOTIFY_TOKEN" ]]; then
    return 1
  fi

  # Map ntfy priority (1-5) to Gotify priority (0-10)
  local gotify_priority
  case "$PRIORITY" in
    1) gotify_priority=1 ;;
    2) gotify_priority=3 ;;
    3) gotify_priority=5 ;;
    4) gotify_priority=7 ;;
    5) gotify_priority=10 ;;
    *) gotify_priority=5 ;;
  esac

  curl -sf \
    -X POST \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -F "title=${TITLE}" \
    -F "message=${MESSAGE}" \
    -F "priority=${gotify_priority}" \
    "${GOTIFY_URL}/message" >/dev/null 2>&1
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo "[notify] Sending: topic=${TOPIC} title=\"${TITLE}\" priority=${PRIORITY}"

# Primary: ntfy
if send_ntfy; then
  echo "[notify] ✅ Sent via ntfy"
  exit 0
fi

echo "[notify] ⚠️  ntfy failed, trying Gotify fallback..."

# Fallback: Gotify
if send_gotify; then
  echo "[notify] ✅ Sent via Gotify (fallback)"
  exit 0
fi

echo "[notify] ❌ All notification channels failed"
exit 1
