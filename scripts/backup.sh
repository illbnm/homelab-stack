#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Full backup with CLI options
# Supports: --target, --dry-run, --restore, --list, --verify
# Targets: local, s3, b2, sftp, r2 (via BACKUP_TARGET env)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --target <stack|all>      Backup target: all, databases, media, configs (default: all)
  --dry-run                 Show what would be backed up without executing
  --restore <backup_id>     Restore from a specific backup
  --list                    List all available backups
  --verify [backup_id]      Verify backup integrity (latest if not specified)
  -h, --help                Show this help

Environment:
  BACKUP_TARGET             Where to store: local, s3, b2, sftp, r2 (default: local)
  BACKUP_RETENTION_DAYS     Days to keep backups (default: 7)

Examples:
  $(basename "$0") --target all
  $(basename "$0") --target media --dry-run
  $(basename "$0") --list
  $(basename "$0") --restore 20260324_030000
  $(basename "$0") --verify
EOF
  exit 0
}

# --- List backups ---
list_backups() {
  log_info "Available backups in $BACKUP_DIR:"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backup directory found"
    return
  fi
  local count=0
  for dir in "$BACKUP_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name size
    name=$(basename "$dir")
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "  $name  ($size)"
    ((count++))
  done
  [[ $count -eq 0 ]] && log_warn "No backups found"
  log_info "Total: $count backups"
}

# --- Verify backup ---
verify_backup() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    target=$(ls -1d "$BACKUP_DIR"/*/ 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null || true)
    [[ -z "$target" ]] && { log_error "No backups found"; exit 1; }
  fi
  local backup_path="$BACKUP_DIR/$target"
  [[ -d "$backup_path" ]] || { log_error "Backup not found: $backup_path"; exit 1; }

  log_info "Verifying backup: $target"
  local errors=0

  for archive in "$backup_path"/*.tar.gz "$backup_path"/vol_*.tar.gz; do
    [[ -f "$archive" ]] || continue
    if tar tzf "$archive" >/dev/null 2>&1; then
      log_info "  ✓ $(basename "$archive")"
    else
      log_error "  ✗ $(basename "$archive") — CORRUPT"
      ((errors++))
    fi
  done

  for sql in "$backup_path"/*.sql "$backup_path"/*.sql.gz "$backup_path"/*.rdb; do
    [[ -f "$sql" ]] || continue
    local size
    size=$(stat -c%s "$sql" 2>/dev/null || stat -f%z "$sql" 2>/dev/null || echo 0)
    if [[ "$size" -gt 0 ]]; then
      log_info "  ✓ $(basename "$sql") ($size bytes)"
    else
      log_error "  ✗ $(basename "$sql") — EMPTY"
      ((errors++))
    fi
  done

  if [[ $errors -eq 0 ]]; then
    log_info "Backup $target: ALL CHECKS PASSED"
  else
    log_error "Backup $target: $errors ERRORS FOUND"
    return 1
  fi
}

# --- Backup volumes ---
backup_volumes() {
  local target="${1:-all}"
  log_info "Backing up Docker volumes (target: $target)..."

  local volumes
  case "$target" in
    all)
      volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
      ;;
    media)
      volumes=$(docker volume ls --format '{{.Name}}' | grep -iE 'media|movie|tv|music|photo|jellyfin|plex|transmission|radarr|sonarr|prowlarr|bazarr' || true)
      ;;
    databases)
      volumes=$(docker volume ls --format '{{.Name}}' | grep -iE 'postgres|redis|mariadb|mysql|database' || true)
      ;;
    configs)
      return 0
      ;;
    *)
      log_error "Unknown target: $target"
      return 1
      ;;
  esac

  if [[ -z "$volumes" ]]; then
    log_warn "No matching volumes found for target: $target"
    return 0
  fi

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# --- Backup configs ---
backup_configs() {
  log_info "Backing up configs..."
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    config/ stacks/ scripts/ 2>/dev/null || true
}

# --- Backup databases ---
backup_databases() {
  log_info "Backing up databases..."

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'postgres\|postgresql'; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
    docker exec "$pg_container" \
      sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
      > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null || \
      log_warn "PostgreSQL backup failed"
  fi

  # MariaDB/MySQL
  if docker ps --format '{{.Names}}' | grep -q 'mariadb\|mysql'; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
    docker exec "$mysql_container" \
      sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
      > "$BACKUP_PATH/mysql_all.sql" 2>/dev/null || \
      log_warn "MySQL backup failed"
  fi

  # Redis BGSAVE
  if docker ps --format '{{.Names}}' | grep -q 'redis'; then
    local redis_container
    redis_container=$(docker ps --format '{{.Names}}' | grep -E 'redis' | head -1)
    docker exec "$redis_container" redis-cli BGSAVE 2>/dev/null || true
    sleep 2
    docker cp "$redis_container:/data/dump.rdb" "$BACKUP_PATH/redis_${TIMESTAMP}.rdb" 2>/dev/null || \
      log_warn "Redis backup failed"
  fi
}

# --- Upload to remote ---
upload_backup() {
  case "$BACKUP_TARGET" in
    local)
      log_info "Target: local ($BACKUP_PATH)"
      ;;
    s3)
      log_info "Uploading to S3/MinIO..."
      command -v mc >/dev/null 2>&1 || { log_warn "mc (MinIO client) not installed"; return; }
      mc cp --recursive "$BACKUP_PATH" "${S3_BUCKET:-homelab-backups}/$(basename "$BACKUP_PATH")/" || \
        log_warn "S3 upload failed"
      ;;
    b2)
      log_info "Uploading to Backblaze B2..."
      command -v rclone >/dev/null 2>&1 || { log_warn "rclone not installed"; return; }
      rclone copy "$BACKUP_PATH" "b2:${B2_BUCKET:-homelab-backups}/$(basename "$BACKUP_PATH")/" || \
        log_warn "B2 upload failed"
      ;;
    r2)
      log_info "Uploading to Cloudflare R2..."
      command -v rclone >/dev/null 2>&1 || { log_warn "rclone not installed"; return; }
      rclone copy "$BACKUP_PATH" "r2:${R2_BUCKET:-homelab-backups}/$(basename "$BACKUP_PATH")/" || \
        log_warn "R2 upload failed"
      ;;
    sftp)
      log_info "Uploading via SFTP..."
      command -v rsync >/dev/null 2>&1 || { log_warn "rsync not installed"; return; }
      rsync -avz "$BACKUP_PATH/" "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH:-/backups/homelab}/$(basename "$BACKUP_PATH")/" || \
        log_warn "SFTP upload failed"
      ;;
    *)
      log_warn "Unknown BACKUP_TARGET: $BACKUP_TARGET (staying local)"
      ;;
  esac
}

# --- Restore ---
restore_backup() {
  local backup_id="$1"
  local backup_path="$BACKUP_DIR/$backup_id"
  [[ -d "$backup_path" ]] || { log_error "Backup not found: $backup_path"; exit 1; }

  echo -e "${YELLOW}WARNING: This will overwrite existing data!${NC}"
  echo "Backup source: $backup_path"
  read -rp "Continue? (yes/no): " confirm
  [[ "$confirm" == "yes" ]] || { log_info "Aborted."; exit 0; }

  [[ -f "$BASE_DIR/config/.env" ]] && source "$BASE_DIR/config/.env"

  # Restore volumes
  log_info "Restoring Docker volumes..."
  for archive in "$backup_path"/vol_*.tar.gz; do
    [[ -f "$archive" ]] || continue
    local vol_name
    vol_name=$(basename "$archive" | sed 's/^vol_//;s/\.tar.gz$//')
    log_info "  Restoring volume: $vol_name"
    docker run --rm \
      -v "${vol_name}:/data" \
      -v "$backup_path:/backup:ro" \
      alpine:3.19 \
      sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$archive") -C /data" 2>/dev/null || \
      log_warn "  Failed to restore volume: $vol_name"
  done

  # Restore configs
  if [[ -f "$backup_path/configs.tar.gz" ]]; then
    log_info "Restoring configs..."
    tar xzf "$backup_path/configs.tar.gz" -C "$BASE_DIR" || log_warn "Config restore failed"
  fi

  # Restore PostgreSQL
  if [[ -f "$backup_path/postgresql_all.sql" ]]; then
    log_info "Restoring PostgreSQL..."
    docker exec -i homelab-postgres psql -U postgres < "$backup_path/postgresql_all.sql" 2>/dev/null || \
      log_warn "PostgreSQL restore failed"
  fi

  # Restore MariaDB
  if [[ -f "$backup_path/mysql_all.sql" ]]; then
    log_info "Restoring MariaDB..."
    docker exec -i homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" < "$backup_path/mysql_all.sql" 2>/dev/null || \
      log_warn "MariaDB restore failed"
  fi

  # Restore Redis
  if ls "$backup_path"/redis_*.rdb 1>/dev/null 2>&1; then
    log_info "Restoring Redis..."
    local rdb_file
    rdb_file=$(ls "$backup_path"/redis_*.rdb | tail -1)
    docker cp "$rdb_file" homelab-redis:/data/dump.rdb 2>/dev/null && \
      docker restart homelab-redis || log_warn "Redis restore failed"
  fi

  log_info "Restore complete! Restart services: cd $BASE_DIR && ./scripts/stack-manager.sh restart-all"
}

# --- Cleanup old backups ---
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# --- Notify (via ntfy if available) ---
notify_result() {
  local status="$1" message="$2"
  if [[ -f "$SCRIPT_DIR/notify.sh" ]]; then
    local priority="default"
    [[ "$status" == "fail" ]] && priority="high"
    "$SCRIPT_DIR/notify.sh" -t "Backup ${status}" -p "$priority" "$message" 2>/dev/null || true
  fi
}

# --- Parse arguments ---
TARGET="all"
ACTION="backup"
RESTORE_ID=""
VERIFY_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --dry-run)  ACTION="dry-run"; shift ;;
    --restore)  ACTION="restore"; RESTORE_ID="$2"; shift 2 ;;
    --list)     ACTION="list"; shift ;;
    --verify)   ACTION="verify"; VERIFY_ID="${2:-}"; shift; [[ -n "${1:-}" ]] && shift || true ;;
    -h|--help)  usage ;;
    *)          log_error "Unknown option: $1"; usage ;;
  esac
done

# --- Execute ---
case "$ACTION" in
  list)
    list_backups
    ;;
  verify)
    verify_backup "$VERIFY_ID"
    ;;
  restore)
    [[ -z "$RESTORE_ID" ]] && { log_error "Missing backup_id for --restore"; exit 1; }
    restore_backup "$RESTORE_ID"
    ;;
  dry-run)
    log_info "DRY RUN — would backup target: $TARGET"
    log_info "Backup path: $BACKUP_PATH"
    log_info "Remote target: $BACKUP_TARGET"
    echo ""
    log_info "Volumes to backup:"
    case "$TARGET" in
      all)      docker volume ls --format '  - {{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || echo "  (none)" ;;
      media)    docker volume ls --format '  - {{.Name}}' | grep -iE 'media|movie|tv|music' || echo "  (none)" ;;
      databases) docker volume ls --format '  - {{.Name}}' | grep -iE 'postgres|redis|mariadb' || echo "  (none)" ;;
      configs)  echo "  - config/, stacks/, scripts/" ;;
    esac
    log_info "Databases: PostgreSQL, MariaDB, Redis (if running)"
    log_info "Config files: yes"
    ;;
  backup)
    log_info "Starting backup — target=$TARGET, timestamp=$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    backup_configs
    backup_volumes "$TARGET"
    [[ "$TARGET" == "all" || "$TARGET" == "databases" ]] && backup_databases

    cleanup_old
    upload_backup

    local total_size
    total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
    log_info "Backup complete: $BACKUP_PATH ($total_size)"
    ls -lh "$BACKUP_PATH/"

    notify_result "success" "Backup $TIMESTAMP completed ($total_size)"
    ;;
esac
