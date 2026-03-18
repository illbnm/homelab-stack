#!/usr/bin/env bash
set -euo pipefail

# Unified notification entrypoint for HomeLab Stack
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority]

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <topic> <title> <message> [priority]" >&2
  exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# optional .env loading
if [[ -f .env ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env | xargs)
fi

NTFY_BASE="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-localhost}}"
GOTIFY_BASE="${GOTIFY_BASE_URL:-https://gotify.${DOMAIN:-localhost}}"

publish_ntfy() {
  local url="${NTFY_BASE%/}/${TOPIC}"
  curl -fsS -X POST "$url" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: warning" \
    -d "${MESSAGE}" >/dev/null
}

publish_gotify() {
  if [[ -z "${GOTIFY_TOKEN:-}" ]]; then
    return 1
  fi

  local prio=5
  case "$PRIORITY" in
    min|low|1|2) prio=2 ;;
    default|3) prio=5 ;;
    high|4) prio=7 ;;
    max|urgent|5) prio=9 ;;
  esac

  curl -fsS -X POST "${GOTIFY_BASE%/}/message?token=${GOTIFY_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"${TITLE}\",\"message\":\"${MESSAGE}\",\"priority\":${prio}}" >/dev/null
}

if publish_ntfy; then
  echo "[OK] ntfy notification sent: ${TOPIC}"
  exit 0
fi

if publish_gotify; then
  echo "[OK] gotify notification sent: ${TOPIC}"
  exit 0
fi

echo "[ERR] failed to publish notification to ntfy and gotify" >&2
exit 1
