#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Backup Automation Script
# Runs scheduled backups via Restic (incremental) and exports to Duplicati.
# Usage: ./backup.sh [daily|weekly|full]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
STACK_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$STACK_DIR/.env" ]; then
  set -a; source "$STACK_DIR/.env"; set +a
fi

BACKUP_NAME="${1:-daily}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$BACKUP_PATH/backup-$BACKUP_NAME-$TIMESTAMP.log"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

backup_docker_volumes() {
  log "Backing up Docker volumes..."
  for vol in $(docker volume ls -q); do
    local vol_path
    vol_path=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || true)
    if [ -n "$vol_path" ] && [ -d "$vol_path" ]; then
      log "  Volume: $vol -> $vol_path"
      docker run --rm \
        -v "$vol_path:/source:ro" \
        -v "$BACKUP_PATH:/backups" \
        restic/restic:0.16.4 \
        -r /backups/restic-repo \
        --verbose \
        backup "/source" \
        --host "$(hostname)" \
        --tag "$vol,docker-volume,$BACKUP_NAME"
    fi
  done
}

backup_data_dirs() {
  if [ -n "${DATA_PATH:-}" ] && [ -d "$DATA_PATH" ]; then
    log "Backing up data directory: $DATA_PATH"
    docker run --rm \
      -v "$DATA_PATH:/data:ro" \
      -v "$BACKUP_PATH:/backups" \
      -e RESTIC_REPOSITORY=/backups/restic-repo \
      -e RESTIC_PASSWORD="${RESTIC_PASSWORD:-}" \
      restic/restic:0.16.4 \
      -r /backups/restic-repo \
      --verbose \
      backup /data \
      --host "$(hostname)" \
      --tag "data,$BACKUP_NAME"
  fi
}

rotate_snapshots() {
  log "Rotating old snapshots..."
  docker run --rm \
    -v "$BACKUP_PATH:/backups" \
    -e RESTIC_REPOSITORY=/backups/restic-repo \
    -e RESTIC_PASSWORD="${RESTIC_PASSWORD:-}" \
    restic/restic:0.16.4 \
    -r /backups/restic-repo \
    forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 1 \
    --prune
}

case "$BACKUP_NAME" in
  daily)
    log "=== Daily backup ==="
    backup_docker_volumes
    backup_data_dirs
    log "Daily backup complete"
    ;;
  weekly)
    log "=== Weekly backup ==="
    backup_docker_volumes
    backup_data_dirs
    rotate_snapshots
    log "Weekly backup complete"
    ;;
  full)
    log "=== Full backup + rotation ==="
    backup_docker_volumes
    backup_data_dirs
    rotate_snapshots
    docker run --rm \
      -v "$BACKUP_PATH:/backups" \
      -e RESTIC_REPOSITORY=/backups/restic-repo \
      -e RESTIC_PASSWORD="${RESTIC_PASSWORD:-}" \
      restic/restic:0.16.4 \
      -r /backups/restic-repo check
    log "Full backup + integrity check complete"
    ;;
  *)
    echo "Usage: $0 [daily|weekly|full]"
    exit 1
    ;;
esac
