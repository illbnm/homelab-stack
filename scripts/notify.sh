#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Notification Script
# Usage: notify.sh <topic> <title> <message> [priority]
#
# All scripts should use this unified interface instead of calling ntfy directly.
# Supports ntfy as the notification backend.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_DIR/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

NTFY_URL="${NTFY_URL:-}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# --- Usage ---
if [[ $# -lt 3 ]]; then
    cat <<'EOF'
HomeLab Notification Script

Usage:
  notify.sh <topic> <title> <message> [priority]

Arguments:
  topic       ntfy topic name (e.g., homelab-backup, homelab-alerts)
  title       Notification title
  message     Notification body text
  priority    min | low | default | high | urgent (default: default)

Environment:
  NTFY_URL    ntfy server URL (e.g., https://ntfy.home.example.com)
  NTFY_TOKEN  Optional: ntfy auth token for protected topics

Examples:
  notify.sh homelab-test "Test" "Hello World"
  notify.sh homelab-alerts "CPU Alert" "CPU usage above 90%" high
  notify.sh homelab-backup "Backup Done" "All stacks backed up" default
  notify.sh homelab-updates "Update" "3 containers updated" low
EOF
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

if [[ -z "$NTFY_URL" ]]; then
    echo "[notify] NTFY_URL not set — notification skipped" >&2
    exit 0
fi

# Build curl args
CURL_ARGS=(
    -sf
    -H "Title: $TITLE"
    -H "Priority: $PRIORITY"
    -d "$MESSAGE"
)

# Add auth token if set
if [[ -n "$NTFY_TOKEN" ]]; then
    CURL_ARGS+=(-H "Authorization: Bearer $NTFY_TOKEN")
fi

# Send notification
if curl "${CURL_ARGS[@]}" "${NTFY_URL}/${TOPIC}" >/dev/null 2>&1; then
    echo "[notify] ✓ Sent: $TITLE → $TOPIC ($PRIORITY)"
else
    echo "[notify] ✗ Failed to send notification to $TOPIC" >&2
    exit 1
fi
