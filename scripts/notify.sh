#!/bin/bash
#
# notify.sh - Unified notification script
#
# Usage:
#   ./notify.sh <topic> <title> <message> [priority]
#
# Examples:
#   ./notify.sh homelab "Test" "Hello World"
#   ./notify.sh homelab "Alert" "Disk space low" "high"
#   ./notify.sh homelab "Info" "Backup completed"
#
# Priority levels: max, high, default, low, min

# Configuration
NTFY_SERVER="${NTFY_SERVER:-http://ntfy:80}"
GOTIFY_SERVER="${GOTIFY_SERVER:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Usage function
usage() {
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo ""
    echo "Arguments:"
    echo "  topic    - ntfy topic (e.g., homelab, alerts)"
    echo "  title    - Notification title"
    echo "  message  - Notification message"
    echo "  priority - Optional: max, high, default, low, min"
    echo ""
    echo "Examples:"
    echo "  $0 homelab 'Test' 'Hello World'"
    echo "  $0 homelab 'Alert' 'Disk full' high"
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    usage
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Map priority names to ntfy values
case "$PRIORITY" in
    max|4) PRIORITY_VALUE="4" ;;
    high|3) PRIORITY_VALUE="3" ;;
    default|2) PRIORITY_VALUE="2" ;;
    low|1) PRIORITY_VALUE="1" ;;
    min|0) PRIORITY_VALUE="0" ;;
    *) PRIORITY_VALUE="2" ;;
esac

# Send notification via ntfy
send_ntfy() {
    curl -s \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY_VALUE" \
        -H "Tags: bell" \
        -d "$MESSAGE" \
        "$NTFY_SERVER/$TOPIC"
}

# Send notification via Gotify (if token is set)
send_gotify() {
    if [ -z "$GOTIFY_TOKEN" ]; then
        echo -e "${YELLOW}Gotify token not set, skipping Gotify${NC}"
        return 1
    fi
    
    # Map priority to Gotify priority (1-5)
    case "$PRIORITY_VALUE" in
        4) GOTIFY_PRIORITY=5 ;;
        3) GOTIFY_PRIORITY=4 ;;
        2) GOTIFY_PRIORITY=3 ;;
        1) GOTIFY_PRIORITY=2 ;;
        0) GOTIFY_PRIORITY=1 ;;
        *) GOTIFY_PRIORITY=3 ;;
    esac
    
    curl -s -X POST "$GOTIFY_SERVER/message?token=$GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$GOTIFY_PRIORITY}"
}

# Main
echo -e "${GREEN}Sending notification...${NC}"
echo "Topic: $TOPIC"
echo "Title: $TITLE"
echo "Message: $MESSAGE"
echo "Priority: $PRIORITY ($PRIORITY_VALUE)"

# Send via ntfy
if send_ntfy; then
    echo -e "${GREEN}✓ ntfy notification sent${NC}"
else
    echo -e "${RED}✗ ntfy notification failed${NC}"
fi

# Send via Gotify (if configured)
if [ -n "$GOTIFY_TOKEN" ]; then
    if send_gotify; then
        echo -e "${GREEN}✓ Gotify notification sent${NC}"
    else
        echo -e "${RED}✗ Gotify notification failed${NC}"
    fi
fi

echo -e "${GREEN}Done!${NC}"
