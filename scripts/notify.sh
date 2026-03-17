#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/notify.sh <topic> <title> <message> [priority]

Examples:
  scripts/notify.sh homelab-test "Test" "Hello World"
  scripts/notify.sh backups "Backup finished" "Nightly backup succeeded" high
EOF
}

json_escape() {
  local value="${1//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

normalize_gotify_priority() {
  case "${1,,}" in
    min|1)
      printf '1'
      ;;
    low|2)
      printf '3'
      ;;
    default|normal|3)
      printf '5'
      ;;
    high|4)
      printf '8'
      ;;
    max|urgent|5)
      printf '10'
      ;;
    *)
      printf '5'
      ;;
  esac
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"
BACKEND="${NOTIFY_BACKEND:-auto}"

send_ntfy() {
  local base_url="${NTFY_BASE_URL:-}"
  if [[ -z "$base_url" && -n "${NTFY_DOMAIN:-}" ]]; then
    base_url="https://${NTFY_DOMAIN}"
  fi

  if [[ -z "$base_url" ]]; then
    echo "NTFY_BASE_URL or NTFY_DOMAIN is required for ntfy delivery." >&2
    return 1
  fi

  local url="${base_url%/}/${TOPIC}"
  local auth_args=()

  if [[ -n "${NTFY_ACCESS_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${NTFY_ACCESS_TOKEN}")
  elif [[ -n "${NTFY_USERNAME:-}" && -n "${NTFY_PASSWORD:-}" ]]; then
    auth_args=(-u "${NTFY_USERNAME}:${NTFY_PASSWORD}")
  fi

  curl --fail --silent --show-error \
    "${auth_args[@]}" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -d "${MESSAGE}" \
    "${url}"
}

send_gotify() {
  local base_url="${GOTIFY_BASE_URL:-}"
  if [[ -z "$base_url" && -n "${GOTIFY_DOMAIN:-}" ]]; then
    base_url="https://${GOTIFY_DOMAIN}"
  fi

  if [[ -z "$base_url" ]]; then
    echo "GOTIFY_BASE_URL or GOTIFY_DOMAIN is required for Gotify delivery." >&2
    return 1
  fi

  if [[ -z "${GOTIFY_APP_TOKEN:-}" ]]; then
    echo "GOTIFY_APP_TOKEN is required for Gotify delivery." >&2
    return 1
  fi

  local gotify_priority
  local payload
  gotify_priority="$(normalize_gotify_priority "$PRIORITY")"
  payload=$(
    printf '{"title":"%s","message":"%s","priority":%s}' \
      "$(json_escape "$TITLE")" \
      "$(json_escape "$MESSAGE")" \
      "$gotify_priority"
  )

  curl --fail --silent --show-error \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${base_url%/}/message?token=${GOTIFY_APP_TOKEN}"
}

case "$BACKEND" in
  ntfy)
    send_ntfy
    ;;
  gotify)
    send_gotify
    ;;
  auto)
    if ! send_ntfy; then
      echo "ntfy delivery failed, trying Gotify fallback..." >&2
      send_gotify
    fi
    ;;
  *)
    echo "Unsupported NOTIFY_BACKEND: $BACKEND" >&2
    exit 1
    ;;
esac
