#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Backup Script (3-2-1 Strategy)
# 3 copies, 2 media types, 1 off-site
#
# Usage:
#   scripts/backup.sh                          # Full backup all stacks
#   scripts/backup.sh --target databases       # Backup databases only
#   scripts/backup.sh --target media,storage   # Backup specific stacks
#   scripts/backup.sh --dry-run                # Show what would be backed up
#   scripts/backup.sh --list                   # List existing backups
#   scripts/backup.sh --restore <id>           # Restore from backup
#   scripts/backup.sh --verify                 # Verify backup integrity
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$BASE_DIR/.env"

[[ -f "$ENV_FILE" ]] && set -a && source "$ENV_FILE" && set +a

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
BACKUP_ID="$TIMESTAMP"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${RESET} $*"; }
log_error() { echo -e "${RED}[backup]${RESET} $*" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }

DRY_RUN=false; TARGET="all"; ACTION="backup"

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-all}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --list) ACTION="list"; shift ;;
    --restore) ACTION="restore"; BACKUP_ID="${2:-}"; shift 2 ;;
    --verify) ACTION="verify"; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# ------------------------------------------------------------------
# List backups
# ------------------------------------------------------------------
do_list() {
  log_step "Existing backups in $BACKUP_DIR"
  if [ -d "$BACKUP_DIR" ]; then
    for d in "$BACKUP_DIR"/*/; do
      [ -d "$d" ] || continue
      local name size
      name=$(basename "$d")
      size=$(du -sh "$d" 2>/dev/null | cut -f1)
      echo "  $name — $size"
    done
  else
    log_warn "No backups found"
  fi
}

# ------------------------------------------------------------------
# Verify backup integrity
# ------------------------------------------------------------------
do_verify() {
  local backup_path="$BACKUP_DIR/$BACKUP_ID"
  log_step "Verifying backup: $BACKUP_ID"
  if [ ! -d "$backup_path" ]; then
    log_error "Backup not found: $backup_path"
    exit 1
  fi
  local ok=0 fail=0
  for f in "$backup_path"/*.tar.gz; do
    [ -f "$f" ] || continue
    if tar tzf "$f" >/dev/null 2>&1; then
      ((ok++))
    else
      log_error "Corrupted: $(basename "$f")"
      ((fail++))
    fi
  done
  log_info "Verified: $ok OK, $fail corrupted"
}

# ------------------------------------------------------------------
# Restore from backup
# ------------------------------------------------------------------
do_restore() {
  local backup_path="$BACKUP_DIR/$BACKUP_ID"
  log_step "Restoring from backup: $BACKUP_ID"
  if [ ! -d "$backup_path" ]; then
    log_error "Backup not found: $backup_path"
    exit 1
  fi
  # Configs restore
  if [ -f "$backup_path/configs.tar.gz" ]; then
    log_info "Restoring configs..."
    tar xzf "$backup_path/configs.tar.gz" -C "$BASE_DIR/" 2>/dev/null || log_warn "Config restore partial"
  fi
  # Database restore
  if [ -f "$backup_path/postgresql_all.sql" ]; then
    log_info "Restoring PostgreSQL..."
    local pg_cont
    pg_cont=$(docker ps --format '{{.Names}}' | grep -E 'homelab-postgres|postgres' | head -1)
    [ -n "$pg_cont" ] && docker exec -i "$pg_cont" psql -U postgres < "$backup_path/postgresql_all.sql" 2>/dev/null || log_warn "PostgreSQL restore skipped"
  fi
  log_info "Restore complete. Restart services for changes to take effect."
}

# ------------------------------------------------------------------
# Dry-run preview
# ------------------------------------------------------------------
do_dry_run() {
  log_step "DRY-RUN: would backup these resources"
  local vols
  vols=$(docker volume ls --format '{{.Name}}' 2>/dev/null | head -20)
  echo "  Volumes: $(echo "$vols" | wc -l)"
  echo "  Configs: $BASE_DIR/config/"
  echo "  Databases: PostgreSQL + MariaDB (if running)"
  echo "  Target: $BACKUP_TARGET"
  echo "  Retention: $RETENTION_DAYS days"
  echo "  Output: $BACKUP_PATH"
}

# ------------------------------------------------------------------
# Backup configs
# ------------------------------------------------------------------
backup_configs() {
  log_info "Backing up configs..."
  if $DRY_RUN; then log_warn "DRY-RUN: skipping"; return; fi
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='*.git' --exclude='node_modules' \
    --exclude='stacks/*/data' --exclude='backups' \
    config/ stacks/ scripts/ tests/ docs/ 2>/dev/null || true
  log_info "  → configs.tar.gz"
}

# ------------------------------------------------------------------
# Backup Docker volumes
# ------------------------------------------------------------------
backup_volumes() {
  local filter="${1:-}"
  log_info "Backing up Docker volumes..."
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    [ -n "$filter" ] && ! echo "$vol" | grep -q "$filter" && continue
    if $DRY_RUN; then log_warn "DRY-RUN: would backup volume $vol"; continue; fi
    docker run --rm -v "${vol}:/data:ro" -v "$BACKUP_PATH:/backup" alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed: $vol"
  done <<< "$volumes"
}

# ------------------------------------------------------------------
# Backup databases
# ------------------------------------------------------------------
backup_databases() {
  log_info "Backing up databases..."
  if $DRY_RUN; then log_warn "DRY-RUN: skipping"; return; fi
  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
    docker exec homelab-postgres sh -c \
      "PGPASSWORD='${POSTGRES_ROOT_PASSWORD:-}' pg_dumpall -U postgres" \
      > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null && log_info "  → postgresql_all.sql" || log_warn "PostgreSQL failed"
  fi
  # MariaDB
  if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
    docker exec homelab-mariadb sh -c \
      "mariadb-dump -u root -p'${MARIADB_ROOT_PASSWORD:-}' --all-databases" \
      > "$BACKUP_PATH/mariadb_all.sql" 2>/dev/null && log_info "  → mariadb_all.sql" || log_warn "MariaDB failed"
  fi
}

# ------------------------------------------------------------------
# Upload to off-site target
# ------------------------------------------------------------------
upload_offsite() {
  case "$BACKUP_TARGET" in
    minio|s3)
      log_info "Uploading to MinIO/S3..."
      mc cp -r "$BACKUP_PATH" "myminio/homelab-backups/$BACKUP_ID/" 2>/dev/null && log_info "Uploaded" || log_warn "S3 upload failed"
      ;;
    b2)
      log_info "Uploading to Backblaze B2..."
      log_warn "B2 not configured — set B2_* env vars"
      ;;
    r2)
      log_info "Uploading to Cloudflare R2..."
      log_warn "R2 not configured — set R2_* env vars"
      ;;
    sftp)
      log_info "Uploading via SFTP..."
      log_warn "SFTP not configured — set SFTP_* env vars"
      ;;
    restic)
      log_info "Pushing to Restic repository..."
      restic -r "http://restic-server:8000" backup "$BACKUP_PATH" 2>/dev/null && log_info "Pushed" || log_warn "Restic push failed"
      ;;
    local|*) log_info "Local backup only (BACKUP_TARGET=$BACKUP_TARGET)" ;;
  esac
}

# ------------------------------------------------------------------
# Cleanup old backups
# ------------------------------------------------------------------
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  if $DRY_RUN; then log_warn "DRY-RUN: skipping"; return; fi
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# ------------------------------------------------------------------
# Notify
# ------------------------------------------------------------------
do_notify() {
  local status="$1" msg="$2" prio="$3" tags="$4"
  if [ -x "$BASE_DIR/scripts/notify.sh" ]; then
    "$BASE_DIR/scripts/notify.sh" backup-status "$status" "$msg" "$prio" "$tags" 2>/dev/null || true
  fi
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
case "$ACTION" in
  list) do_list; exit 0 ;;
  verify) do_verify; exit 0 ;;
  restore) do_restore; exit 0 ;;
esac

if $DRY_RUN; then
  do_dry_run; exit 0
fi

log_step "Backup — $BACKUP_ID"
mkdir -p "$BACKUP_PATH"

# Filter volumes by target stack
VOL_FILTER=""
case "$TARGET" in
  all) VOL_FILTER="" ;;
  databases) VOL_FILTER="postgres|redis|mariadb|mysql" ;;
  media) VOL_FILTER="jellyfin|sonarr|radarr|prowlarr|qbittorrent" ;;
  storage) VOL_FILTER="nextcloud|minio|syncthing|filebrowser" ;;
  monitoring) VOL_FILTER="grafana|prometheus|loki|alertmanager" ;;
  sso) VOL_FILTER="authentik" ;;
  *) VOL_FILTER="$TARGET" ;;
esac

backup_configs
backup_volumes "$VOL_FILTER"
[ "$TARGET" = "all" ] || [ "$TARGET" = "databases" ] && backup_databases
upload_offsite
cleanup_old

# Summary
SIZE=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
log_info "Backup complete: $BACKUP_PATH ($SIZE)"
ls -lh "$BACKUP_PATH/" 2>/dev/null | tail -n +2

do_notify "Backup Complete" "Backup $BACKUP_ID ($SIZE) — $(date)" 3 check