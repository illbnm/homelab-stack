#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backup"
RESTIC_REPO="http://localhost:8000/repo"
NTFY_URL="https://ntfy.localhost/homelab-backups"

usage() {
  echo "Usage: $0 --target <stack|all> [--dry-run] [--restore <id>] [--list] [--verify]"
  exit 1
}

TARGET=""
DRY_RUN=""
RESTORE_ID=""
LIST=""
VERIFY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --restore) RESTORE_ID="$2"; shift 2 ;;
    --list) LIST=1; shift ;;
    --verify) VERIFY=1; shift ;;
    *) usage ;;
  esac
done

[ -z "$TARGET" ] && usage

notify() {
  curl -s -H "Title: $1" -H "Priority: default" -d "$2" "$NTFY_URL" > /dev/null 2>&1 || true
}

run_backup() {
  local vol=$1
  if [ -n "$DRY_RUN" ]; then
    echo "[DRY-RUN] Would backup volume: $vol"
  else
    echo "[$(date)] Backing up $vol..."
    restic backup $vol -r "$RESTIC_REPO" && notify "Backup OK" "Volume $vol backed up" || notify "Backup FAILED" "Volume $vol failed"
  fi
}

if [ -n "$LIST" ]; then
  restic snapshots -r "$RESTIC_REPO"
elif [ -n "$VERIFY" ]; then
  restic check -r "$RESTIC_REPO"
elif [ -n "$RESTORE_ID" ]; then
  restic restore "$RESTORE_ID" -r "$RESTIC_REPO" --target /restore
else
  run_backup /data
fi
