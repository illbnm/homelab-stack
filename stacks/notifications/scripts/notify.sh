#!/usr/bin/env bash
# =============================================================================
# notify.sh — Unified notification sender for ntfy and Gotify
# Usage:
#   ntfy:   ./notify.sh ntfy   <topic>  <title> [<message>] [tags]
#   gotify: ./notify.sh gotify <token> <title> <message> [priority]
# Priority (gotify): 1=min, 3=normal, 5=high, 7=max, 9=emergency  [default: 5]
# =============================================================================

set -euo pipefail

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.${DOMAIN:-localhost}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "${GREEN}[notify]${NC} $*"; }
err() { echo -e "${RED}[notify]${NC} $*" >&2; exit 1; }

notify_ntfy() {
  local topic="$1" title="$2" message="${3:-}" tags="${4:-}"
  local url="${NTFY_SERVER}/${topic}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    "$url" \
    -H "Title: $title" \
    ${tags:+-H "Tags: $tags"} \
    ${message:+-d "$message"})
  [[ "$code" == 200 ]] && log "ntfy OK  topic=$topic" \
    || err "ntfy FAILED (HTTP $code)"
}

notify_gotify() {
  local token="$1" title="$2" message="$3" priority="${4:-5}"
  local url="${GOTIFY_URL}/message"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -F "token=$token" \
    -F "title=$title" \
    -F "message=$message" \
    -F "priority=$priority" \
    "$url")
  [[ "$code" == 200 || "$code" == 202 ]] && log "gotify OK  priority=$priority" \
    || err "gotify FAILED (HTTP $code)"
}

usage() {
  echo -e "${YELLOW}Usage:${NC}"
  echo "  ntfy:   $0 ntfy   <topic>  <title> [<message>] [tags]"
  echo "  gotify: $0 gotify <token> <title> <message> [priority]"
  echo ""
  echo "Examples:"
  echo "  $0 ntfy alerts \"Disk full\" \"sda1 at 95%\" warning,floppy_disk"
  echo "  $0 gotify ABPwGt2...8xX \"Deploy done\" \"Server restarted\" 5"
}

[[ $# -lt 3 ]] && { usage; err "Not enough arguments"; }

case "$1" in
  ntfy)
    [[ $# -lt 3 ]] && { usage; err "ntfy requires: topic title [message] [tags]"; }
    notify_ntfy "$2" "$3" "${4:-}" "${5:-}"
    ;;
  gotify)
    [[ $# -lt 4 ]] && { usage; err "gotify requires: token title message [priority]"; }
    notify_gotify "$2" "$3" "$4" "${5:-5}"
    ;;
  *) usage; err "Unknown backend: $1";;
esac