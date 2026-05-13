#!/usr/bin/env bash
# HomeLab Backup Script - 3-2-1 Strategy
# Usage: backup.sh --target <stack|all> [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.env" 2>/dev/null || true

# Defaults
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RESTIC_REPO="${RESTIC_REPO:-rest:http://restic-server:8000/}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-changeme}"
NTFY_URL="${NTFY_URL:-}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"

export RESTIC_REPOSITORY="$RESTIC_REPO"
export RESTIC_PASSWORD

usage() {
  cat <<EOF
HomeLab Backup Tool

Usage: backup.sh --target <stack|all> [options]

Options:
  --target all          Backup all stack data volumes
  --target <name>       Backup specific stack (media, monitoring, etc.)
  --dry-run             Show what would be backed up
  --restore <id>        Restore from specified snapshot
  --list                List all snapshots
  --verify              Verify backup integrity
  --help                Show this help

Environment:
  BACKUP_TARGET=local|s3|b2|sftp|r2  Storage backend (default: local)
  RESTIC_REPO                         Restic repository URL
  RESTIC_PASSWORD                     Repository password
EOF
}

notify() {
  local msg="$1"
  if [ -n "$NTFY_URL" ]; then
    curl -sf -d "$msg" "$NTFY_URL/$NTFY_TOPIC" 2>/dev/null || true
  fi
  echo "$msg"
}

init_repo() {
  if ! restic snapshots &>/dev/null; then
    echo "Initializing restic repository..."
    restic init
  fi
}

backup_volumes() {
  local target="$1"
  local volumes_dir="/var/lib/docker/volumes"

  if [ "$target" = "all" ]; then
    echo "Backing up all Docker volumes..."
    restic backup "$volumes_dir" --tag "all" --tag "$(date +%Y-%m-%d)"
  else
    echo "Backing up stack: $target"
    # Find volumes matching stack name
    local matching
    matching=$(docker volume ls --format '{{.Name}}' | grep -i "$target" || true)
    if [ -z "$matching" ]; then
      echo "No volumes found for stack: $target"
      return 1
    fi
    for vol in $matching; do
      restic backup "$volumes_dir/$vol" --tag "$target" --tag "$(date +%Y-%m-%d)"
    done
  fi
}

list_snapshots() {
  restic snapshots --compact
}

verify_backup() {
  echo "Verifying backup integrity..."
  restic check
  echo "✓ Backup integrity verified"
}

restore_snapshot() {
  local snapshot_id="$1"
  echo "Restoring snapshot: $snapshot_id"
  restic restore "$snapshot_id" --target /
  echo "✓ Restore complete"
}

# Parse arguments
TARGET=""
DRY_RUN=false
ACTION="backup"
SNAPSHOT_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --list) ACTION="list"; shift ;;
    --verify) ACTION="verify"; shift ;;
    --restore) ACTION="restore"; SNAPSHOT_ID="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Execute
case $ACTION in
  backup)
    if [ -z "$TARGET" ]; then
      echo "Error: --target required"; usage; exit 1
    fi
    init_repo
    if [ "$DRY_RUN" = true ]; then
      echo "[DRY RUN] Would backup: $TARGET"
      restic backup --dry-run /var/lib/docker/volumes 2>&1 | head -20
    else
      backup_volumes "$TARGET"
      notify "✓ Backup complete: $TARGET ($(date))"
    fi
    ;;
  list) list_snapshots ;;
  verify) verify_backup ;;
  restore)
    if [ -z "$SNAPSHOT_ID" ]; then
      echo "Error: snapshot ID required"; exit 1
    fi
    restore_snapshot "$SNAPSHOT_ID"
    notify "✓ Restore complete: $SNAPSHOT_ID"
    ;;
esac
