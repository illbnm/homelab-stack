#!/bin/bash
# Unified notification script for homelab-stack
# Supports ntfy and Gotify notification services
# Usage: notify.sh <topic> <title> <message> [priority] [tags]

set -e

# Default configuration
NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.${DOMAIN:-example.com}}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:8080}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Priority mapping (1=min, 5=max, default=3)
declare -A PRIORITY_MAP=(
    ["min"]=1 ["1"]=1 ["low"]=2 ["2"]=2
    ["default"]=3 ["3"]=3 ["normal"]=3
    ["high"]=4 ["4"]=4 ["urgent"]=5 ["5"]=5 ["max"]=5
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

# Help function
show_help() {
    cat << EOF
Unified Notification Script for Homelab Stack

Usage: notify.sh <topic> <title> <message> [priority] [tags]

Arguments:
  topic     Notification topic/channel (e.g., homelab-alerts, homelab-updates)
  title     Notification title
  message   Notification message body
  priority  Priority level (default: 3)
            Options: min(1), low(2), default(3), high(4), max(5)
  tags      Comma-separated tags (e.g., warning,error,success)

Environment Variables:
  NTFY_BASE_URL    Ntfy server URL (default: https://ntfy.\${DOMAIN})
  GOTIFY_URL       Gotify server URL (default: http://gotify:8080)
  GOTIFY_TOKEN     Gotify application token (optional)
  DOMAIN           Your domain for ntfy (default: example.com)

Examples:
  # Basic notification
  notify.sh homelab-test "Test" "Hello World"

  # High priority alert
  notify.sh homelab-alerts "Alert" "Service down" high error

  # With tags
  notify.sh homelab-updates "Update" "Container updated" normal success,docker

  # Using environment variables
  DOMAIN=mydomain.com notify.sh test "Test" "Message"
EOF
}

# Send notification via ntfy
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    local tags="$5"

    local json_payload="{
        \"topic\": \"${topic}\",
        \"title\": \"${title}\",
        \"message\": \"${message}\",
        \"priority\": ${priority}"

    if [[ -n "$tags" ]]; then
        # Convert comma-separated tags to array
        IFS=',' read -ra TAG_ARRAY <<< "$tags"
        local tags_json="["
        for tag in "${TAG_ARRAY[@]}"; do
            tags_json+="\"${tag}\","
        done
        tags_json="${tags_json%,}]"
        json_payload+=", \"tags\": ${tags_json}"
    fi

    json_payload+="}"

    log "Sending ntfy notification to topic: ${topic}"
    
    if curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${NTFY_TOKEN:-}" \
        -d "${json_payload}" \
        "${NTFY_BASE_URL}"; then
        log "ntfy notification sent successfully"
    else
        error "Failed to send ntfy notification"
        return 1
    fi
}

# Send notification via Gotify
send_gotify() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    local tags="$5"

    # Gotify doesn't have topics, so we include it in the title
    local gotify_title="[${topic}] ${title}"
    
    local json_payload="{
        \"title\": \"${gotify_title}\",
        \"message\": \"${message}\",
        \"priority\": ${priority}"

    if [[ -n "$tags" ]]; then
        json_payload+=", \"extras\": {
            \"client::display\": {
                \"contentType\": \"text/markdown\"
            }
        }"
    fi

    json_payload+="}"

    if [[ -z "$GOTIFY_TOKEN" ]]; then
        log "Gotify token not set, skipping Gotify notification"
        return 0
    fi

    log "Sending Gotify notification"
    
    if curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
        -d "${json_payload}" \
        "${GOTIFY_URL}/message"; then
        log "Gotify notification sent successfully"
    else
        error "Failed to send Gotify notification"
        return 1
    fi
}

# Main function
main() {
    # Check for help
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Validate arguments
    if [[ $# -lt 3 ]]; then
        error "Missing required arguments"
        show_help
        exit 1
    fi

    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-default}"
    local tags="$5"

    # Validate and normalize priority
    if [[ -n "${PRIORITY_MAP[$priority]}" ]]; then
        priority="${PRIORITY_MAP[$priority]}"
    else
        # Try to parse as number
        if [[ "$priority" =~ ^[1-5]$ ]]; then
            priority="$priority"
        else
            error "Invalid priority: $priority. Using default (3)"
            priority=3
        fi
    fi

    # Sanitize topic (only allow alphanumeric, dash, underscore)
    local sanitized_topic=$(echo "$topic" | tr -cd '[:alnum:]-_')

    if [[ "$sanitized_topic" != "$topic" ]]; then
        log "Sanitized topic from '$topic' to '$sanitized_topic'"
        topic="$sanitized_topic"
    fi

    log "Sending notification:"
    log "  Topic:    ${topic}"
    log "  Title:    ${title}"
    log "  Message:  ${message}"
    log "  Priority: ${priority}"
    [[ -n "$tags" ]] && log "  Tags:     ${tags}"

    # Send notifications
    local errors=0

    # Send via ntfy (primary)
    if ! send_ntfy "$topic" "$title" "$message" "$priority" "$tags"; then
        ((errors++))
    fi

    # Send via Gotify (fallback/alternative)
    if ! send_gotify "$topic" "$title" "$message" "$priority" "$tags"; then
        ((errors++))
    fi

    if [[ $errors -eq 2 ]]; then
        error "All notification methods failed"
        exit 1
    elif [[ $errors -eq 1 ]]; then
        log "One notification method failed, but others succeeded"
    else
        log "All notifications sent successfully"
    fi
}

# Make script executable and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure script is executable
    if [[ ! -x "$0" ]]; then
        chmod +x "$0"
    fi
    main "$@"
fi