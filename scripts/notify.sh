#!/bin/bash
# =============================================================================
# notify.sh - Unified notification script
# Usage: notify.sh <topic> <title> <message> [priority]
# 
# Examples:
#   notify.sh homelab "Backup Complete" "All databases backed up successfully"
#   notify.sh alerts "Critical" "Disk usage above 90%" high
#   notify.sh updates "Container Updated" "nginx updated to v1.25"
# =============================================================================

set -euo pipefail

# Configuration
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
FALLBACK_ENABLED="${FALLBACK_ENABLED:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

usage() {
    cat << EOF
Usage: $(basename "$0") <topic> <title> <message> [priority]

Arguments:
    topic      - ntfy topic name (e.g., homelab, alerts, updates)
    title      - Notification title
    message    - Notification body text
    priority   - Optional: min, low, default, high, urgent (default: default)

Environment Variables:
    NTFY_URL      - ntfy server URL (default: https://ntfy.\$DOMAIN)
    NTFY_TOKEN    - ntfy access token (optional, for protected topics)
    GOTIFY_URL    - Gotify server URL (default: https://gotify.\$DOMAIN)
    GOTIFY_TOKEN  - Gotify application token (optional, for fallback)
    FALLBACK_ENABLED - Enable Gotify fallback (default: true)

Examples:
    # Basic notification
    $(basename "$0") homelab "Test" "Hello World"

    # High priority alert
    $(basename "$0") alerts "Critical" "Disk usage above 90%" high

    # Container update notification
    $(basename "$0") updates "Container Updated" "nginx updated to v1.25"

    # From environment
    DOMAIN=home.example.com $(basename "$0") test "Title" "Message"
EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Send notification via ntfy
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-default}"

    local url="${NTFY_URL}/${topic}"
    local cmd=("curl" "-s" "-o" "/dev/null" "-w" "%{http_code}")

    cmd+=("-H" "Title: ${title}")
    cmd+=("-H" "Priority: ${priority}")
    cmd+=("-H" "Tags: homelab")

    if [[ -n "${NTFY_TOKEN}" ]]; then
        cmd+=("-H" "Authorization: Bearer ${NTFY_TOKEN}")
    fi

    cmd+=("-d" "${message}" "${url}")

    local http_code
    http_code=$("${cmd[@]}")

    if [[ "${http_code}" == "200" ]]; then
        log_info "ntfy notification sent successfully to topic: ${topic}"
        return 0
    else
        log_error "ntfy notification failed with HTTP ${http_code}"
        return 1
    fi
}

# Send notification via Gotify
send_gotify() {
    local title="$1"
    local message="$2"
    local priority="${3:-5}"

    if [[ -z "${GOTIFY_TOKEN}" ]]; then
        log_warn "GOTIFY_TOKEN not set, skipping Gotify notification"
        return 1
    fi

    local url="${GOTIFY_URL}/message"
    local http_code

    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"${title}\",\"message\":\"${message}\",\"priority\":${priority}}" \
        "${url}")

    if [[ "${http_code}" == "200" ]]; then
        log_info "Gotify notification sent successfully"
        return 0
    else
        log_error "Gotify notification failed with HTTP ${http_code}"
        return 1
    fi
}

# Map ntfy priority to Gotify priority (1-10)
map_priority() {
    local ntfy_priority="$1"
    case "${ntfy_priority}" in
        min)     echo "1" ;;
        low)     echo "3" ;;
        default) echo "5" ;;
        high)    echo "8" ;;
        urgent)  echo "10" ;;
        *)       echo "5" ;;
    esac
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Check arguments
if [[ $# -lt 3 ]]; then
    usage
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Validate priority
case "${PRIORITY}" in
    min|low|default|high|urgent) ;;
    *)
        log_warn "Invalid priority '${PRIORITY}', using 'default'"
        PRIORITY="default"
        ;;
esac

log_info "Sending notification..."
log_info "  Topic: ${TOPIC}"
log_info "  Title: ${TITLE}"
log_info "  Priority: ${PRIORITY}"

# Try ntfy first
if send_ntfy "${TOPIC}" "${TITLE}" "${MESSAGE}" "${PRIORITY}"; then
    exit 0
fi

# Fallback to Gotify if enabled
if [[ "${FALLBACK_ENABLED}" == "true" ]]; then
    log_info "Attempting fallback to Gotify..."
    gotify_priority=$(map_priority "${PRIORITY}")
    if send_gotify "${TITLE}" "${MESSAGE}" "${gotify_priority}"; then
        exit 0
    fi
fi

log_error "All notification methods failed"
exit 1
