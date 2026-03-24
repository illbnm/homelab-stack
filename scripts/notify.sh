#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Notification Script
# Usage: notify.sh <topic> <title> <message> [priority]
# 
# Examples:
#   notify.sh homelab-alerts "Server Alert" "High CPU usage detected" high
#   notify.sh backups "Backup Complete" "Database backup finished successfully"
# =============================================================================

set -euo pipefail

# Configuration
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN:-localhost}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
USE_NTFY="${USE_NTFY:-true}"
USE_GOTIFY="${USE_GOTIFY:-false}"

# Priority levels: default, low, high, urgent
PRIORITY="${4:-default}"

# Colors for terminal output
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

# Send notification via ntfy
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    local headers=(
        -H "Title: $title"
        -H "Priority: $priority"
    )
    
    # Add authentication if configured
    if [[ -n "${NTFY_USER:-}" ]] && [[ -n "${NTFY_PASSWORD:-}" ]]; then
        headers+=(-u "${NTFY_USER}:${NTFY_PASSWORD}")
    fi
    
    if curl -sf "${headers[@]}" -d "$message" "${NTFY_URL}/${topic}"; then
        log_info "ntfy notification sent to topic: $topic"
        return 0
    else
        log_error "Failed to send ntfy notification"
        return 1
    fi
}

# Send notification via Gotify
send_gotify() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    # Convert priority to Gotify format (0-10)
    local gotify_priority=5
    case "$priority" in
        low)     gotify_priority=2 ;;
        default) gotify_priority=5 ;;
        high)    gotify_priority=8 ;;
        urgent)  gotify_priority=10 ;;
    esac
    
    if [[ -z "$GOTIFY_TOKEN" ]]; then
        log_warn "GOTIFY_TOKEN not set, skipping Gotify notification"
        return 0
    fi
    
    local json_data
    json_data=$(cat <<EOF
{
    "title": "$title",
    "message": "$message",
    "priority": $gotify_priority,
    "extras": {
        "client::display": {
            "contentType": "text/plain"
        }
    }
}
EOF
)
    
    if curl -sf -X POST \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "${GOTIFY_URL}/message"; then
        log_info "Gotify notification sent"
        return 0
    else
        log_error "Failed to send Gotify notification"
        return 1
    fi
}

# Main notification function
send_notification() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    local success=true
    
    # Send via ntfy (primary)
    if [[ "$USE_NTFY" == "true" ]]; then
        if ! send_ntfy "$topic" "$title" "$message" "$priority"; then
            success=false
        fi
    fi
    
    # Send via Gotify (backup/alternative)
    if [[ "$USE_GOTIFY" == "true" ]]; then
        if ! send_gotify "$topic" "$title" "$message" "$priority"; then
            success=false
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Print usage
print_usage() {
    cat <<EOF
Usage: notify.sh <topic> <title> <message> [priority]

Arguments:
    topic     - The notification topic/channel (e.g., homelab-alerts, backups)
    title     - Notification title
    message   - Notification message body
    priority  - Optional: default, low, high, urgent (default: default)

Environment Variables:
    NTFY_URL        - ntfy server URL (default: https://ntfy.\$DOMAIN)
    NTFY_USER       - ntfy username (optional)
    NTFY_PASSWORD   - ntfy password (optional)
    GOTIFY_URL      - Gotify server URL
    GOTIFY_TOKEN    - Gotify application token
    USE_NTFY        - Enable ntfy notifications (default: true)
    USE_GOTIFY      - Enable Gotify notifications (default: false)

Examples:
    # Send alert notification
    notify.sh homelab-alerts "Server Alert" "High CPU usage detected" high

    # Send backup notification
    notify.sh backups "Backup Complete" "Database backup finished successfully"

    # Send low priority info
    notify.sh info "Info" "Container updated" low

Integration Examples:
    # Watchtower notifications
    WATCHTOWER_NOTIFICATION_URL=script:///path/to/notify.sh
    
    # Alertmanager webhook (via ntfy webhook)
    # Configure alertmanager to POST to https://ntfy.example.com/alerts

EOF
}

# Main entry point
main() {
    if [[ $# -lt 3 ]]; then
        print_usage
        exit 1
    fi
    
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-default}"
    
    # Validate priority
    case "$priority" in
        low|default|high|urgent)
            ;;
        *)
            log_warn "Invalid priority '$priority', using 'default'"
            priority="default"
            ;;
    esac
    
    send_notification "$topic" "$title" "$message" "$priority"
}

# Run main
main "$@"