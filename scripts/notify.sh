#!/bin/bash
# =============================================================================
# Unified Notification Script
# 
# Usage: 
#   ./notify.sh <topic> <title> <message> [priority]
#   ./notify.sh homelab-test "Test" "Hello World" default
#
# Priority levels: 
#   -1 (low), 0 (default), 1 (high), 2 (max), 3 (emergency)
#
# Examples:
#   ./notify.sh homelab "Deployment Complete" "Updated to v1.2.3" high
#   ./notify.sh homelab-alerts "Critical" "Server down!" emergency
# =============================================================================

set -e

# Configuration - modify these or set environment variables
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Default priority mapping
declare -A PRIORITY_MAP=(
    ["low"]="-1"
    ["default"]="0"
    ["high"]="1"
    ["max"]="2"
    ["emergency"]="3"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 <topic> <title> <message> [priority]

Arguments:
    topic      - ntfy topic (e.g., homelab, homelab-alerts)
    title      - Notification title
    message    - Notification body
    priority   - Priority level: low, default, high, max, emergency (default: default)

Examples:
    $0 homelab-test "Test" "Hello World"
    $0 homelab-alerts "Server Alert" "CPU usage high!" high
    $0 homelab "Deployment" "Updated to v1.2.3" default

Environment Variables:
    NTFY_URL    - ntfy server URL (default: https://ntfy.sh)
    GOTIFY_URL  - Gotify server URL (default: http://gotify:80)
    GOTIFY_TOKEN - Gotify app token

EOF
    exit 1
}

# Validate arguments
if [ $# -lt 3 ]; then
    usage
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Validate priority
if [[ -z "${PRIORITY_MAP[$PRIORITY]}" ]]; then
    log_warn "Invalid priority: $PRIORITY, using 'default'"
    PRIORITY="default"
fi

PRIORITY_VALUE="${PRIORITY_MAP[$PRIORITY]}"

# Send via ntfy (primary)
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    log_info "Sending ntfy notification to topic: $topic"
    
    local ntfy_full_url="${NTFY_URL}/${topic}"
    
    if curl -sf \
        -H "Title: ${title}" \
        -H "Priority: ${priority}" \
        -H "Tags: notification" \
        -d "${message}" \
        "${ntfy_full_url}" > /dev/null 2>&1; then
        log_info "ntfy notification sent successfully"
        return 0
    else
        log_error "Failed to send ntfy notification"
        return 1
    fi
}

# Send via Gotify (fallback/alternative)
send_gotify() {
    local title="$1"
    local message="$2"
    local priority="$3"
    
    if [ -z "$GOTIFY_TOKEN" ]; then
        log_warn "GOTIFY_TOKEN not set, skipping Gotify"
        return 1
    fi
    
    log_info "Sending Gotify notification"
    
    # Map priority to Gotify's priority (0-10)
    local gotify_priority=$(( (priority + 1) * 2 ))  # Convert -1~3 to 0~8
    
    if curl -sf \
        -X POST "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"${title}\",\"message\":\"${message}\",\"priority\":${gotify_priority}}" > /dev/null 2>&1; then
        log_info "Gotify notification sent successfully"
        return 0
    else
        log_error "Failed to send Gotify notification"
        return 1
    fi
}

# Main execution
log_info "Sending notification:"
log_info "  Topic:    $TOPIC"
log_info "  Title:    $TITLE"
log_info "  Message:  $MESSAGE"
log_info "  Priority: $PRIORITY (value: $PRIORITY_VALUE)"

# Try ntfy first
if send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY_VALUE"; then
    log_info "Notification delivery complete"
    exit 0
fi

# Fallback to Gotify if ntfy fails
log_warn "ntfy failed, trying Gotify..."
if send_gotify "$TITLE" "$MESSAGE" "$PRIORITY_VALUE"; then
    log_info "Notification delivery complete (via Gotify)"
    exit 0
fi

log_error "All notification methods failed"
exit 1