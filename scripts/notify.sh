#!/bin/bash
#
# Unified Notification Script for Homelab Stack
# Sends notifications via ntfy and/or Gotify
#
# Usage: notify.sh <topic> <title> <message> [priority]
#
# Priority levels:
#   1 = Minion (lowest)
#   2 = Default
#   3 = Elevated
#   4 = Urgent
#   5 = Emergency (highest)
#
# Examples:
#   notify.sh homelab-test "Test" "Hello World"
#   notify.sh alerts "Critical" "Database down!" 5
#   notify.sh watchtower "Update" "Container updated" 2
#

set -e

# Configuration
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo ""
    echo "Arguments:"
    echo "  topic    - Notification topic/channel"
    echo "  title    - Notification title"
    echo "  message  - Notification message"
    echo "  priority - Optional: 1-5 (default: 2)"
    echo ""
    echo "Examples:"
    echo "  $0 homelab-test \"Test\" \"Hello World\""
    echo "  $0 alerts \"Critical\" \"Database down!\" 5"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-2}"

# Validate priority
if ! [[ "$PRIORITY" =~ ^[1-5]$ ]]; then
    error "Priority must be between 1 and 5"
fi

# Map priority to ntfy priority names
case "$PRIORITY" in
    1) PRIORITY_NAME="minion" ;;
    2) PRIORITY_NAME="default" ;;
    3) PRIORITY_NAME="elevated" ;;
    4) PRIORITY_NAME="urgent" ;;
    5) PRIORITY_NAME="emergency" ;;
esac

log "Sending notification to topic: $TOPIC"
log "Title: $TITLE"
log "Message: $MESSAGE"
log "Priority: $PRIORITY ($PRIORITY_NAME)"

# Send to ntfy
send_ntfy() {
    log "Sending to ntfy..."
    
    if curl -sf \
        -X POST \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY" \
        -H "Tags: bell" \
        "$NTFY_URL/$TOPIC" \
        -d "$MESSAGE" > /dev/null 2>&1; then
        log "${GREEN}✓ ntfy notification sent successfully${NC}"
        return 0
    else
        log "${YELLOW}⚠ ntfy notification failed (service may be unavailable)${NC}"
        return 1
    fi
}

# Send to Gotify
send_gotify() {
    if [ -z "$GOTIFY_TOKEN" ]; then
        log "${YELLOW}⚠ Gotify token not set, skipping Gotify notification${NC}"
        return 1
    fi
    
    log "Sending to Gotify..."
    
    if curl -sf \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$TITLE\", \"message\": \"$MESSAGE\", \"priority\": $PRIORITY}" \
        "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" > /dev/null 2>&1; then
        log "${GREEN}✓ Gotify notification sent successfully${NC}"
        return 0
    else
        log "${YELLOW}⚠ Gotify notification failed (service may be unavailable)${NC}"
        return 1
    fi
}

# Main execution
NTFY_RESULT=0
GOTIFY_RESULT=0

send_ntfy || NTFY_RESULT=1
send_gotify || GOTIFY_RESULT=1

# Summary
echo ""
log "=== Notification Summary ==="
if [ $NTFY_RESULT -eq 0 ]; then
    log "${GREEN}✓ ntfy: Success${NC}"
else
    log "${YELLOW}⚠ ntfy: Failed${NC}"
fi

if [ $GOTIFY_RESULT -eq 0 ]; then
    log "${GREEN}✓ Gotify: Success${NC}"
elif [ -z "$GOTIFY_TOKEN" ]; then
    log "${YELLOW}⚠ Gotify: Skipped (no token)${NC}"
else
    log "${YELLOW}⚠ Gotify: Failed${NC}"
fi

# Exit with error if both failed
if [ $NTFY_RESULT -ne 0 ] && [ $GOTIFY_RESULT -ne 0 ]; then
    error "All notification channels failed"
fi

exit 0
