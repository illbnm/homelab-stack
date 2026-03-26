#!/bin/bash
# =============================================================================
# Unified Notification Script — HomeLab Stack
# Usage: ./notify.sh <priority> <title> <message> [tags]
#
# Examples:
#   ./notify.sh low "Backup Complete" "PostgreSQL backup saved (250MB)"
#   ./notify.sh high "ALERT: Disk Full" "Server disk usage at 95%" "warning,server"
#   ./notify.sh normal "Update Available" "New Docker images ready" -all
#
# Requires: NTFY_TOKEN and/or GOTIFY_TOKEN in .env
# =============================================================================
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Load environment
if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

# Defaults
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab}"
GOTIFY_SERVER="${GOTIFY_SERVER:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Priority mapping
declare -A PRIORITY_MAP=(
    [low]=5
    [normal]=3
    [high]=8
    [urgent]=10
)
PRIORITY="${1:-normal}"
TITLE="${2:-Notification}"
MESSAGE="${3:-}"
TAGS="${4:-}"

# Resolve numeric priority
if [[ -v PRIORITY_MAP[$PRIORITY] ]]; then
    NUM_PRIORITY="${PRIORITY_MAP[$PRIORITY]}"
else
    NUM_PRIORITY=3
fi

# Detect targets
send_ntfy() {
    local msg="$1"
    local tags="${2:-}"

    local curl_opts=("-s" "-o" "/dev/null" "-w" "%{http_code}")

    if [[ -n "${NTFY_TOKEN:-}" ]]; then
        curl "${curl_opts[@]}" -H "Authorization: Bearer ${NTFY_TOKEN}" \
            -H "X-Priority: ${NUM_PRIORITY}" \
            -H "X-Tags: ${tags}" \
            -H "X-Title: ${TITLE}" \
            -d "${msg}" \
            "${NTFY_SERVER}/${NTFY_TOPIC}" 2>/dev/null | grep -q "200\|429"
    else
        curl "${curl_opts[@]}" \
            -H "X-Priority: ${NUM_PRIORITY}" \
            -H "X-Tags: ${tags}" \
            -H "X-Title: ${TITLE}" \
            -d "${msg}" \
            "${NTFY_SERVER}/${NTFY_TOPIC}" 2>/dev/null | grep -q "200\|429"
    fi
}

send_gotify() {
    local msg="$1"
    local tags="${2:-}"

    if [[ -z "${GOTIFY_TOKEN:-}" ]]; then
        return 1
    fi

    local priority="${NUM_PRIORITY}"
    [[ "$PRIORITY" == "low" ]] && priority=1
    [[ "$PRIORITY" == "normal" ]] && priority=5
    [[ "$PRIORITY" == "high" ]] && priority=8
    [[ "$PRIORITY" == "urgent" ]] && priority=10

    local payload
    payload=$(printf '{"title":"%s","message":"%s","priority":%d,"extras":{"tags":"%s"}}' \
        "$TITLE" "$msg" "$priority" "$tags")

    curl -sf -o /dev/null \
        -H "Content-Type: application/json" \
        -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
        -d "$payload" \
        "${GOTIFY_SERVER}/message" 2>/dev/null
    return 0
}

# Main
if [[ -z "$MESSAGE" ]]; then
    echo "Usage: $0 <priority> <title> <message> [tags]"
    echo "  priority: low, normal, high, urgent"
    echo "  tags: comma-separated tags (e.g. warning,server)"
    exit 1
fi

FAILED=0

# Send to ntfy
if send_ntfy "$MESSAGE" "$TAGS"; then
    echo "[notify] ntfy: OK (priority=$PRIORITY)"
else
    echo "[notify] ntfy: FAILED (token may be missing)"
    FAILED=1
fi

# Send to Gotify (if configured)
if send_gotify "$MESSAGE" "$TAGS"; then
    echo "[notify] gotify: OK"
else
    if [[ -z "${GOTIFY_TOKEN:-}" ]]; then
        echo "[notify] gotify: SKIPPED (GOTIFY_TOKEN not set)"
    else
        echo "[notify] gotify: FAILED"
        FAILED=1
    fi
fi

exit $FAILED
