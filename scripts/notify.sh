#!/bin/bash
#
# notify.sh - Unified notification script for Homelab Stack
# Supports both ntfy and Gotify backends with auto-detection
#
# Usage: ./notify.sh <topic> <title> <message> [priority]
#
# Environment variables:
#   NTFY_ENABLED=true      - Enable ntfy (default)
#   GOTIFY_ENABLED=false  - Enable Gotify (optional)
#   NTFY_SERVER           - ntfy server URL (default: http://ntfy:80)
#   GOTIFY_SERVER         - Gotify server URL (default: http://gotify:80)
#   GOTIFY_TOKEN          - Gotify app token
#

set -e

# Configuration
NTFY_SERVER="${NTFY_SERVER:-http://ntfy:80}"
GOTIFY_SERVER="${GOTIFY_SERVER:-http://gotify:80}"
NTFY_ENABLED="${NTFY_ENABLED:-true}"
GOTIFY_ENABLED="${GOTIFY_ENABLED:-false}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# JSON escape function
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr -d '\n'
}

# Normalize Gotify priority (map ntfy priorities to Gotify)
normalize_gotify_priority() {
    local priority="$1"
    case "$priority" in
        1|min|low)
            echo "1"
            ;;
        2|low)
            echo "2"
            ;;
        3|medium|default)
            echo "4"
            ;;
        4|high)
            echo "7"
            ;;
        5|urgent|max|critical)
            echo "10"
            ;;
        *)
            echo "4"  # default to normal
            ;;
    esac
}

# Send notification via ntfy
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-3}"
    
    # Convert priority names to numbers
    case "$priority" in
        min|low) priority=1 ;;
        2) priority=2 ;;
        medium|default) priority=3 ;;
        high) priority=4 ;;
        urgent|max|critical) priority=5 ;;
    esac
    
    local url="${NTFY_SERVER}/${topic}"
    
    log_info "Sending ntfy notification: $title"
    
    if curl -s -w "\n%{http_code}" -o /dev/null \
        -H "Title: $(json_escape "$title")" \
        -H "Priority: $priority" \
        -H "Tags: bell" \
        -d "$(json_escape "$message")" \
        "$url" | grep -q "200\|201\|202"; then
        log_info "ntfy notification sent successfully"
        return 0
    else
        log_error "Failed to send ntfy notification"
        return 1
    fi
}

# Send notification via Gotify
send_gotify() {
    local title="$1"
    local message="$2"
    local priority="$3"
    
    if [ -z "$GOTIFY_TOKEN" ]; then
        log_warn "GOTIFY_TOKEN not set, skipping Gotify"
        return 1
    fi
    
    local normalized_priority
    normalized_priority=$(normalize_gotify_priority "$priority")
    
    local url="${GOTIFY_SERVER}/message?token=${GOTIFY_TOKEN}"
    
    log_info "Sending Gotify notification: $title"
    
    if curl -s -w "\n%{http_code}" -o /dev/null \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$(json_escape "$title")\", \"message\": \"$(json_escape "$message")\", \"priority\": $normalized_priority}" \
        "$url" | grep -q "200\|201\|202"; then
        log_info "Gotify notification sent successfully"
        return 0
    else
        log_error "Failed to send Gotify notification"
        return 1
    fi
}

# Main function
main() {
    local topic="${1:-}"
    local title="${2:-}"
    local message="${3:-}"
    local priority="${4:-3}"
    
    # Validate arguments
    if [ -z "$topic" ] || [ -z "$title" ] || [ -z "$message" ]; then
        echo "Usage: $0 <topic> <title> <message> [priority]"
        echo ""
        echo "Arguments:"
        echo "  topic    - ntfy topic or Gotify target"
        echo "  title    - Notification title"
        echo "  message  - Notification message"
        echo "  priority - Priority level (1-5 or min/low/medium/high/urgent)"
        echo ""
        echo "Environment variables:"
        echo "  NTFY_ENABLED    - Enable ntfy (default: true)"
        echo "  GOTIFY_ENABLED  - Enable Gotify (default: false)"
        echo "  NTFY_SERVER     - ntfy server URL"
        echo "  GOTIFY_SERVER   - Gotify server URL"
        echo "  GOTIFY_TOKEN    - Gotify app token"
        echo ""
        echo "Examples:"
        echo "  $0 homelab-test 'Test' 'Hello World'"
        echo "  $0 homelab-alerts 'Alert' 'High CPU usage' high"
        exit 1
    fi
    
    local sent=false
    
    # Send via ntfy
    if [ "$NTFY_ENABLED" = "true" ]; then
        if send_ntfy "$topic" "$title" "$message" "$priority"; then
            sent=true
        fi
    fi
    
    # Send via Gotify (optional)
    if [ "$GOTIFY_ENABLED" = "true" ]; then
        if send_gotify "$title" "$message" "$priority"; then
            sent=true
        fi
    fi
    
    if [ "$sent" = "false" ]; then
        log_error "No notifications were sent"
        exit 1
    fi
}

# Run main function
main "$@"
