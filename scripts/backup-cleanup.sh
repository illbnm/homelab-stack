#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
DELETED=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Remove backups older than retention period
for dir in "$BACKUP_DIR"/*/; do
    while IFS= read -r -d '' old; do
        log "Removing old backup: $old"
        rm -rf "$old"
        ((DELETED++))
    done < <(find "$dir" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -print0 2>/dev/null)
done

log "Cleanup complete: removed $DELETED backup(s) older than ${RETENTION_DAYS} days"
