#!/usr/bin/env bash
# =============================================================================
# Unified Notification Script
# Usage: ./scripts/notify.sh <topic> <title> <message> [priority]
# Example: ./scripts/notify.sh alerts "Deployment" "App deployed successfully" high
#
# Priority levels: min, low, default, high, urgent (default: default)
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    source "${PROJECT_ROOT}/.env"
else
    echo -e "${RED}Error: .env file not found${NC}" >&2
    echo "Please run: cp .env.example .env && ./scripts/setup-env.sh" >&2
    exit 1
fi

# Default values
DOMAIN="${DOMAIN:-localhost}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
GOTIFY_URL="${GOTIFY_URL:-https://gotify.${DOMAIN}}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
NTFY_USER="${NTFY_USER:-}"
NTFY_PASS="${NTFY_PASS:-}"

# Parse arguments
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <topic> <title> <message> [priority]" >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  topic    - Notification topic/channel (e.g., alerts, updates)" >&2
    echo "  title    - Notification title" >&2
    echo "  message  - Notification message body" >&2
    echo "  priority - Priority level: min|low|default|high|urgent (default: default)" >&2
    echo "" >&2
    echo "Environment variables:" >&2
    echo "  NTFY_URL         - ntfy server URL (default: https://ntfy.\${DOMAIN})" >&2
    echo "  NTFY_USER        - ntfy username (optional)" >&2
    echo "  NTFY_PASS        - ntfy password (optional)" >&2
    echo "  GOTIFY_URL       - Gotify server URL (default: https://gotify.\${DOMAIN})" >&2
    echo "  GOTIFY_TOKEN     - Gotify app token (required for fallback)" >&2
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# Validate priority
case "${PRIORITY}" in
    min|low|default|high|urgent)
        ;;
    *)
        echo -e "${RED}Error: Invalid priority '${PRIORITY}'${NC}" >&2
        echo "Valid priorities: min, low, default, high, urgent" >&2
        exit 1
        ;;
esac

# Function to send ntfy notification
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"

    local curl_args=(-s -X POST "${NTFY_URL}/${topic}")
    curl_args+=(-d "${message}")
    curl_args+=(-H "Title: ${title}")
    curl_args+=(-H "Priority: ${priority}")

    # Add authentication if configured
    if [[ -n "${NTFY_USER}" ]] && [[ -n "${NTFY_PASS}" ]]; then
        curl_args+=(-u "${NTFY_USER}:${NTFY_PASS}")
    fi

    if curl "${curl_args[@]}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to send Gotify notification
send_gotify() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"

    if [[ -z "${GOTIFY_TOKEN}" ]]; then
        echo -e "${YELLOW}Warning: Gotify token not configured${NC}" >&2
        return 1
    fi

    # Map ntfy priorities to Gotify priorities (1-10)
    local gotify_priority
    case "${priority}" in
        min)   gotify_priority=1 ;;
        low)   gotify_priority=3 ;;
        default) gotify_priority=5 ;;
        high)  gotify_priority=8 ;;
        urgent) gotify_priority=10 ;;
    esac

    local curl_args=(-s -X POST "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}")
    curl_args+=(-H "Content-Type: application/json")
    curl_args+=(-d "{\"title\":\"${title}\",\"message\":\"${message}\",\"priority\":${gotify_priority}}")

    if curl "${curl_args[@]}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main notification logic
main() {
    echo -e "${GREEN}Sending notification...${NC}" >&2

    # Try ntfy first
    if send_ntfy "${TOPIC}" "${TITLE}" "${MESSAGE}" "${PRIORITY}"; then
        echo -e "${GREEN}✓ Sent via ntfy${NC}" >&2
        exit 0
    fi

    # Fallback to Gotify
    echo -e "${YELLOW}ntfy failed, trying Gotify fallback...${NC}" >&2
    if send_gotify "${TOPIC}" "${TITLE}" "${MESSAGE}" "${PRIORITY}"; then
        echo -e "${GREEN}✓ Sent via Gotify${NC}" >&2
        exit 0
    fi

    # Both failed
    echo -e "${RED}✗ Failed to send notification via both ntfy and Gotify${NC}" >&2
    exit 1
}

main
