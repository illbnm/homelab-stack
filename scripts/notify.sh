#!/bin/bash
# ===========================================
# Unified Notification Script for HomeLab
# Usage: notify.sh <topic> <title> <message> [priority]
#
# Examples:
#   notify.sh homelab-alerts "Test" "Hello World"
#   notify.sh homelab-alerts "Critical" "Server down!" 5
#   notify.sh backups "Backup Complete" "All databases backed up" 3
#
# The ntfy server URL is read from NTFY_URL env var
# or defaults to http://ntfy:80 (internal Docker network)
# ===========================================

set -e

# Configuration
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOKEN="${NTFY_TOKEN:-}"  # Optional: for authenticated topics

# Validate arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <topic> <title> <message> [priority]"
    echo ""
    echo "Arguments:"
    echo "  topic     - ntfy topic name (e.g., homelab-alerts, backups)"
    echo "  title     - Notification title"
    echo "  message   - Notification message body"
    echo "  priority  - Optional: 1 (min) to 5 (max), default: 3"
    echo ""
    echo "Examples:"
    echo "  $0 homelab-alerts 'Test' 'Hello World'"
    echo "  $0 homelab-alerts 'Critical' 'Server down!' 5"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

# Validate priority (1-5)
if ! [[ "$PRIORITY" =~ ^[1-5]$ ]]; then
    echo "Error: Priority must be 1-5 (got: $PRIORITY)"
    exit 1
fi

# Build curl command
CURL_CMD="curl -s -o /dev/null -w '%{http_code}'"
CURL_CMD+=" -H 'Title: $TITLE'"
CURL_CMD+=" -H 'Priority: $PRIORITY'"
CURL_CMD+=" -H 'Tags: homelab'"

# Add auth token if configured
if [ -n "$NTFY_TOKEN" ]; then
    CURL_CMD+=" -H 'Authorization: Bearer $NTFY_TOKEN'"
fi

# Add message data
CURL_CMD+=" -d '$MESSAGE'"

# Build full URL
FULL_URL="${NTFY_URL}/${TOPIC}"

# Send notification
echo "Sending notification to topic '$TOPIC'..."
echo "  URL: $FULL_URL"
echo "  Title: $TITLE"
echo "  Priority: $PRIORITY"

HTTP_CODE=$(eval "$CURL_CMD '$FULL_URL'")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Notification sent successfully!"
    exit 0
else
    echo "✗ Failed to send notification (HTTP $HTTP_CODE)"
    exit 1
fi