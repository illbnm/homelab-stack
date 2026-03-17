#!/bin/bash
# =============================================================================
# Unified Notification Script
# Usage: ./notify.sh <topic> <title> <message> [priority]
#
# Examples:
#   ./notify.sh homelab-test "Test" "Hello World"
#   ./notify.sh homelab-alerts "Warning" "High CPU usage" "high"
# =============================================================================

set -e

# Configuration
NTFY_BASE_URL="${NTFY_BASE_URL:-http://localhost:8076}"
NTFY_DEFAULT_TOPIC="${NTFY_DEFAULT_TOPIC:-homelab}"
GOTIFY_URL="${GOTIFY_URL:-http://localhost:8077}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Priority mapping
declare -A PRIORITY_MAP=(
    ["low"]=1
    ["medium"]=2
    ["high"]=3
    ["urgent"]=4
    ["max"]=5
)

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
    local priority="${4:-2}"
    
    # Convert priority name to number
    if [[ -n "${PRIORITY_MAP[$priority]}" ]]; then
        priority="${PRIORITY_MAP[$priority]}"
    fi
    
    local url="${NTFY_BASE_URL}/${topic}"
    
    log_info "Sending ntfy notification to ${url}"
    log_info "Title: ${title}, Priority: ${priority}"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Title: ${title}" \
        -H "Priority: ${priority}" \
        -H "Tags: notification" \
        -d "${message}" \
        "${url}")
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log_info "ntfy notification sent successfully"
        return 0
    else
        log_error "ntfy notification failed (HTTP ${http_code})"
        return 1
    fi
}

# Send notification via Gotify
send_gotify() {
    local title="$1"
    local message="$2"
    local priority="${3:-2}"
    
    if [[ -z "${GOTIFY_TOKEN}" ]]; then
        log_warn "GOTIFY_TOKEN not set, skipping Gotify notification"
        return 1
    fi
    
    # Convert priority name to number
    if [[ -n "${PRIORITY_MAP[$priority]}" ]]; then
        priority="${PRIORITY_MAP[$priority]}"
    fi
    
    local url="${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}"
    
    log_info "Sending Gotify notification"
    log_info "Title: ${title}, Priority: ${priority}"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"${message}\", \"title\": \"${title}\", \"priority\": ${priority}}" \
        "${url}")
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log_info "Gotify notification sent successfully"
        return 0
    else
        log_error "Gotify notification failed (HTTP ${http_code})"
        return 1
    fi
}

# Main
main() {
    local topic="${1:-${NTFY_DEFAULT_TOPIC}}"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    if [[ -z "$title" ]] || [[ -z "$message" ]]; then
        echo "Usage: $0 <topic> <title> <message> [priority]"
        echo ""
        echo "Arguments:"
        echo "  topic    - ntfy topic (default: homelab)"
        echo "  title    - Notification title"
        echo "  message  - Notification message"
        echo "  priority - Priority (low, medium, high, urgent, max)"
        echo ""
        echo "Examples:"
        echo "  $0 homelab-test 'Test' 'Hello World'"
        echo "  $0 homelab-alerts 'Warning' 'High CPU' 'high'"
        exit 1
    fi
    
    log_info "Sending notification..."
    log_info "Topic: ${topic}"
    
    # Send to ntfy (primary)
    send_ntfy "$topic" "$title" "$message" "$priority"
    
    # Send to Gotify (secondary, if configured)
    if [[ -n "${GOTIFY_TOKEN}" ]]; then
        send_gotify "$title" "$message" "$priority" || true
    fi
    
    log_info "Notification sent!"
}

main "$@"
