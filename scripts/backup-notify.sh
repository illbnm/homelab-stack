#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — ntfy Notification
# Usage: backup-notify.sh <status> <message> <backup_id>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

STATUS="${1:-unknown}"
MESSAGE="${2:-No details}"
BACKUP_ID="${3:-unknown}"
NTFY_TOPIC="${NTFY_BACKUP_TOPIC:-homelab-backup}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
HOSTNAME=$(hostname)

# Build title and priority based on status
case "$STATUS" in
  success)
    TITLE="✅ Backup Successful"
    PRIORITY="low"
    TAGS="white_check_mark,homelab"
    ;;
  failure)
    TITLE="❌ Backup Failed"
    PRIORITY="high"
    TAGS="rotating_light,homelab"
    ;;
  warning)
    TITLE="⚠️ Backup Warning"
    PRIORITY="default"
    TAGS="warning,homelab"
    ;;
  *)
    TITLE="📦 Backup Update"
    PRIORITY="default"
    TAGS="package,homelab"
    ;;
esac

# Send notification
if [[ -n "${NTFY_TOKEN:-}" ]]; then
  curl -s \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: $TAGS" \
    -H "Authorization: Bearer $NTFY_TOKEN" \
    -d "[$HOSTNAME] $MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1 || true
else
  curl -s \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: $TAGS" \
    -d "[$HOSTNAME] $MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1 || true
fi

echo "[notify] Sent $STATUS notification for backup $BACKUP_ID"
