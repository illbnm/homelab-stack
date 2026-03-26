#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack - Unified Notification Script
# =============================================================================
# Usage:
#   ./notify.sh <topic> <title> <message> [priority]
#   ./notify.sh ntfy <topic> <message> [priority]
#   ./notify.sh gotify <title> <message> [priority]
#
# Examples:
#   ./notify.sh homelab "Test Alert" "Hello from Homelab!"
#   ./notify.sh homelab "Update Complete" "Watchtower updated 3 containers" 3
#   ./notify.sh gotify "System Alert" "Disk space low" 5
# =============================================================================

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
    set -a && source "$ENV_FILE" && set +a
fi

# Default values
DOMAIN="${DOMAIN:-localhost}"
NTFY_BASE_URL="https://ntfy.${DOMAIN}"
GOTIFY_BASE_URL="https://gotify.${DOMAIN}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Send notification to ntfy
notify_ntfy() {
    local topic="$1"
    local message="$2"
    local priority="${3:-3}"
    
    local url="${NTFY_BASE_URL}/${topic}"
    
    log_info "Sending ntfy notification to topic: $topic"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Title: Homelab Notification" \
        -H "Priority: $priority" \
        -H "Tags: homelab" \
        -d "$message" \
        "$url" 2>&1) || true
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        log_info "ntfy notification sent successfully"
        return 0
    else
        log_error "ntfy notification failed (HTTP $http_code): $body"
        return 1
    fi
}

# Send notification to Gotify
notify_gotify() {
    local title="$1"
    local message="$2"
    local priority="${3:-3}"
    
    if [[ -z "$GOTIFY_TOKEN" ]]; then
        log_error "GOTIFY_TOKEN not set. Cannot send Gotify notification."
        return 1
    fi
    
    local url="${GOTIFY_BASE_URL}/message"
    
    log_info "Sending Gotify notification: $title"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "message=$(echo "$message" | sed 's/ /%20/g')&title=$(echo "$title" | sed 's/ /%20/g')&priority=$priority" \
        "$url" 2>&1) || true
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        log_info "Gotify notification sent successfully"
        return 0
    else
        log_error "Gotify notification failed (HTTP $http_code): $body"
        return 1
    fi
}

# Send to both ntfy and Gotify
notify_both() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-3}"
    
    notify_ntfy "$topic" "[$title] $message" "$priority"
    notify_gotify "$title" "$message" "$priority"
}

# Main usage
usage() {
    echo -e "${GREEN}Usage:${NC}"
    echo "  $0 <topic> <title> <message> [priority]     Send to ntfy (default)"
    echo "  $0 ntfy <topic> <message> [priority]         Send to ntfy explicitly"
    echo "  $0 gotify <title> <message> [priority]       Send to Gotify"
    echo "  $0 both <topic> <title> <message> [priority] Send to both"
    echo ""
    echo -e "${GREEN}Priority levels:${NC}"
    echo "  1 - Min (lowest)"
    echo "  3 - Default (normal)"
    echo "  5 - Max (urgent)"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 homelab 'Test' 'Hello World'"
    echo "  $0 homelab 'Alert' 'Disk space low' 5"
    echo "  $0 gotify 'System' 'Container updated'"
    echo "  $0 both alerts 'Update' '3 containers updated'"
    exit 1
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    usage
fi

case "$1" in
    ntfy)
        if [[ $# -lt 3 ]]; then usage; fi
        notify_ntfy "$2" "$3" "${4:-3}"
        ;;
    gotify)
        if [[ $# -lt 3 ]]; then usage; fi
        notify_gotify "$2" "$3" "${4:-3}"
        ;;
    both)
        if [[ $# -lt 4 ]]; then usage; fi
        notify_both "$2" "$3" "$4" "${5:-3}"
        ;;
    -h|--help)
        usage
        ;;
    *)
        # Default: send to ntfy with topic as first arg
        notify_ntfy "$1" "$2" "${3:-3}"
        ;;
esac
