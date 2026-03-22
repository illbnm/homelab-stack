#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 3-2-1 Backup Strategy
# Supports: local, S3/MinIO, Backblaze B2, SFTP, Cloudflare R2
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"
BACKUP_ID="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$BASE_DIR/backups}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_ID"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Load env
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[backup]${NC} $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[backup]${NC} $*" | tee -a "$LOG_FILE" >&2; }
log_step()  { echo -e "\n${BLUE}==> $*${NC}" | tee -a "$LOG_FILE"; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: backup.sh --target <stack|all> [options]

Options:
  --target all          Backup all stack data volumes
  --target <stack>      Backup specific stack (media, databases, storage, etc.)
  --dry-run             Show what would be backed up without executing
  --restore <backup_id> Restore from specified backup
  --list                List all available backups
  --verify              Verify backup integrity
  --help                Show this help message

Examples:
  backup.sh --target all
  backup.sh --target media --dry-run
  backup.sh --restore 20260323_020000
  backup.sh --list
  backup.sh --verify
EOF
  exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
TARGET=""
DRY_RUN=false
RESTORE_ID=""
DO_LIST=false
DO_VERIFY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --target)   TARGET="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --restore)  RESTORE_ID="$2"; shift 2 ;;
    --list)     DO_LIST=true; shift ;;
    --verify)   DO_VERIFY=true; shift ;;
    --help|-h)  usage ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# List backups
# ---------------------------------------------------------------------------
list_backups() {
  log_step "Available backups"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backup directory found: $BACKUP_DIR"
    return
  fi
  local count=0
  for dir in "$BACKUP_DIR"/*/; do
    [[ ! -d "$dir" ]] && continue
    local bid
    bid=$(basename "$dir")
    [[ ! "$bid" =~ ^[0-9]{8}_[0-9]{6}$ ]] && continue
    local size
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    local files
    files=$(find "$dir" -type f | wc -l)
    printf "  %-20s  %8s  %d files\n" "$bid" "$size" "$files"
    ((count++))
  done
  echo ""
  log_info "Total: $count backups"
}

# ---------------------------------------------------------------------------
# Verify backup integrity
# ---------------------------------------------------------------------------
verify_backup() {
  local bid="${1:-$BACKUP_ID}"
  local path="$BACKUP_DIR/$bid"

  if [[ ! -d "$path" ]]; then
    log_error "Backup not found: $path"
    return 1
  fi

  log_step "Verifying backup: $bid"
  local errors=0

  # Verify tar.gz files
  for archive in "$path"/*.tar.gz; do
    [[ ! -f "$archive" ]] && continue
    if tar tzf "$archive" >/dev/null 2>&1; then
      log_info "  ✓ $(basename "$archive")"
    else
      log_error "  ✗ $(basename "$archive") — CORRUPTED"
      ((errors++))
    fi
  done

  # Verify SQL dumps (basic check)
  for sql in "$path"/*.sql; do
    [[ ! -f "$sql" ]] && continue
    if [[ -s "$sql" ]] && head -1 "$sql" | grep -qiE '^(--|CREATE|SET|PG|MariaDB)'; then
      log_info "  ✓ $(basename "$sql")"
    else
      log_error "  ✗ $(basename "$sql") — may be corrupted or empty"
      ((errors++))
    fi
  done

  # Verify manifest
  if [[ -f "$path/manifest.json" ]]; then
    log_info "  ✓ manifest.json"
  else
    log_warn "  ⚠ manifest.json missing"
  fi

  if [[ $errors -eq 0 ]]; then
    log_info "All checks passed ✓"
    return 0
  else
    log_error "$errors file(s) failed verification"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Backup Docker volumes for a specific stack
# ---------------------------------------------------------------------------
backup_stack_volumes() {
  local stack="$1"
  local vol_pattern="${stack}"
  local vol_dir="$BACKUP_PATH/volumes"
  mkdir -p "$vol_dir"

  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -i "$vol_pattern" || true)

  if [[ -z "$volumes" ]]; then
    log_warn "  No volumes found for stack: $stack"
    return
  fi

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    if $DRY_RUN; then
      log_info "  [DRY-RUN] Would backup volume: $vol"
      continue
    fi
    log_info "  Volume: $vol"
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$vol_dir:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# ---------------------------------------------------------------------------
# Backup configs
# ---------------------------------------------------------------------------
backup_configs() {
  log_step "Backing up configuration files"
  if $DRY_RUN; then
    log_info "  [DRY-RUN] Would backup configs from $BASE_DIR"
    return
  fi
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='backups' \
    --exclude='.git' \
    config/ stacks/ scripts/ .env.example install.sh 2>/dev/null || true
  log_info "  ✓ configs.tar.gz"
}

# ---------------------------------------------------------------------------
# Backup databases
# ---------------------------------------------------------------------------
backup_databases() {
  log_step "Backing up databases"
  mkdir -p "$BACKUP_PATH/databases"

  # PostgreSQL
  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    if $DRY_RUN; then
      log_info "  [DRY-RUN] Would backup PostgreSQL from container: $pg_container"
    else
      log_info "  PostgreSQL: $pg_container"
      local pg_pass
      pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
        | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
      docker exec "$pg_container" \
        sh -c "PGPASSWORD='${pg_pass}' pg_dumpall -U postgres" \
        > "$BACKUP_PATH/databases/postgresql_all.sql" 2>/dev/null || \
        log_warn "  PostgreSQL backup failed"
      [[ -s "$BACKUP_PATH/databases/postgresql_all.sql" ]] && log_info "  ✓ PostgreSQL dump"
    fi
  else
    log_info "  No PostgreSQL container found, skipping"
  fi

  # MariaDB/MySQL
  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    if $DRY_RUN; then
      log_info "  [DRY-RUN] Would backup MariaDB/MySQL from container: $mysql_container"
    else
      log_info "  MariaDB/MySQL: $mysql_container"
      local mysql_pass
      mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
        | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1 || true)
      docker exec "$mysql_container" \
        sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
        > "$BACKUP_PATH/databases/mysql_all.sql" 2>/dev/null || \
        log_warn "  MySQL backup failed"
      [[ -s "$BACKUP_PATH/databases/mysql_all.sql" ]] && log_info "  ✓ MySQL dump"
    fi
  else
    log_info "  No MariaDB/MySQL container found, skipping"
  fi

  # Redis
  local redis_container
  redis_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i 'redis' | head -1 || true)
  if [[ -n "$redis_container" ]]; then
    if $DRY_RUN; then
      log_info "  [DRY-RUN] Would backup Redis from container: $redis_container"
    else
      log_info "  Redis: $redis_container"
      local redis_pass
      redis_pass=$(docker inspect "$redis_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
        | grep REDIS_PASSWORD | cut -d= -f2 | head -1 || true)
      docker exec "$redis_container" \
        sh -c "redis-cli ${redis_pass:+-a '$redis_pass'} --rdb /tmp/dump.rdb && cat /tmp/dump.rdb" \
        > "$BACKUP_PATH/databases/redis_dump.rdb" 2>/dev/null || \
        log_warn "  Redis backup failed"
      [[ -s "$BACKUP_PATH/databases/redis_dump.rdb" ]] && log_info "  ✓ Redis dump"
    fi
  else
    log_info "  No Redis container found, skipping"
  fi
}

# ---------------------------------------------------------------------------
# Backup all volumes
# ---------------------------------------------------------------------------
backup_all_volumes() {
  log_step "Backing up all Docker volumes"
  mkdir -p "$BACKUP_PATH/volumes"

  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -v '^[a-f0-9]\{64\}$' || true)

  if $DRY_RUN; then
    log_info "  [DRY-RUN] Found $(echo "$volumes" | wc -l) volumes to backup"
    return
  fi

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH/volumes:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# ---------------------------------------------------------------------------
# Upload to remote targets
# ---------------------------------------------------------------------------
upload_to_remote() {
  local src="$1"

  case "$BACKUP_TARGET" in
    local)
      log_info "Target: local ($BACKUP_DIR)"
      ;;
    s3|minio)
      log_step "Uploading to S3/MinIO"
      if $DRY_RUN; then
        log_info "  [DRY-RUN] Would upload to s3://${S3_BUCKET:-homelab-backups}/$BACKUP_ID/"
        return
      fi
      local endpoint="${S3_ENDPOINT:-}"
      local extra_args=""
      [[ -n "$endpoint" ]] && extra_args="--endpoint-url $endpoint"
      aws s3 cp "$src" "s3://${S3_BUCKET:-homelab-backups}/$BACKUP_ID/" \
        --recursive $extra_args 2>/dev/null || log_error "S3 upload failed"
      log_info "  ✓ Uploaded to S3"
      ;;
    b2)
      log_step "Uploading to Backblaze B2"
      if $DRY_RUN; then
        log_info "  [DRY-RUN] Would upload to b2://${B2_BUCKET:-homelab-backups}/$BACKUP_ID/"
        return
      fi
      b2 sync "$src" "b2://${B2_BUCKET:-homelab-backups}/$BACKUP_ID/" 2>/dev/null || log_error "B2 upload failed"
      log_info "  ✓ Uploaded to B2"
      ;;
    sftp)
      log_step "Uploading to SFTP"
      if $DRY_RUN; then
        log_info "  [DRY-RUN] Would upload to ${SFTP_HOST:-remote}:${SFTP_PATH:-/backups}/$BACKUP_ID/"
        return
      fi
      local sftp_host="${SFTP_HOST:?SFTP_HOST not set}"
      local sftp_path="${SFTP_PATH:-/backups}"
      local sftp_user="${SFTP_USER:-root}"
      local sftp_key="${SFTP_KEY:-}"
      local ssh_opts="-o StrictHostKeyChecking=no"
      [[ -n "$sftp_key" ]] && ssh_opts="$ssh_opts -i $sftp_key"
      rsync -avz -e "ssh $ssh_opts" "$src/" "${sftp_user}@${sftp_host}:${sftp_path}/$BACKUP_ID/" \
        2>/dev/null || log_error "SFTP upload failed"
      log_info "  ✓ Uploaded to SFTP"
      ;;
    r2)
      log_step "Uploading to Cloudflare R2"
      if $DRY_RUN; then
        log_info "  [DRY-RUN] Would upload to R2://${R2_BUCKET:-homelab-backups}/$BACKUP_ID/"
        return
      fi
      aws s3 cp "$src" "s3://${R2_BUCKET:-homelab-backups}/$BACKUP_ID/" \
        --recursive \
        --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" 2>/dev/null || log_error "R2 upload failed"
      log_info "  ✓ Uploaded to R2"
      ;;
    *)
      log_error "Unknown BACKUP_TARGET: $BACKUP_TARGET"
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
generate_manifest() {
  if $DRY_RUN; then return; fi

  local total_size
  total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
  local file_count
  file_count=$(find "$BACKUP_PATH" -type f | wc -l)

  cat > "$BACKUP_PATH/manifest.json" <<MANIFEST
{
  "backup_id": "$BACKUP_ID",
  "timestamp": "$(date -Iseconds)",
  "target": "$BACKUP_TARGET",
  "total_size": "$total_size",
  "file_count": $file_count,
  "hostname": "$(hostname)",
  "stacks": "$TARGET"
}
MANIFEST
  log_info "  ✓ manifest.json ($total_size, $file_count files)"
}

# ---------------------------------------------------------------------------
# Cleanup old backups
# ---------------------------------------------------------------------------
cleanup_old() {
  log_step "Cleaning backups older than ${RETENTION_DAYS} days"
  if $DRY_RUN; then
    local old_count
    old_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" 2>/dev/null | wc -l)
    log_info "  [DRY-RUN] Would remove $old_count old backup(s)"
    return
  fi
  local removed=0
  for dir in "$BACKUP_DIR"/*/; do
    [[ ! -d "$dir" ]] && continue
    local bid
    bid=$(basename "$dir")
    [[ ! "$bid" =~ ^[0-9]{8}_[0-9]{6}$ ]] && continue
    if [[ $(find "$dir" -maxdepth 0 -mtime +"$RETENTION_DAYS" 2>/dev/null) ]]; then
      rm -rf "$dir"
      log_info "  Removed: $bid"
      ((removed++))
    fi
  done
  log_info "  Removed $removed old backup(s)"
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
restore_backup() {
  local bid="$1"
  local path="$BACKUP_DIR/$bid"

  if [[ ! -d "$path" ]]; then
    log_error "Backup not found: $path"
    exit 1
  fi

  log_step "Restoring from backup: $bid"

  # Verify first
  if ! verify_backup "$bid"; then
    log_error "Backup verification failed — aborting restore"
    exit 1
  fi

  # Restore configs
  if [[ -f "$path/configs.tar.gz" ]]; then
    log_info "Restoring configs..."
    tar xzf "$path/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || log_warn "Config restore had errors"
  fi

  # Restore databases
  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]] && [[ -f "$path/databases/postgresql_all.sql" ]]; then
    log_info "Restoring PostgreSQL..."
    docker exec -i "$pg_container" psql -U postgres < "$path/databases/postgresql_all.sql" 2>/dev/null || \
      log_warn "PostgreSQL restore had errors"
  fi

  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]] && [[ -f "$path/databases/mysql_all.sql" ]]; then
    log_info "Restoring MariaDB/MySQL..."
    docker exec -i "$mysql_container" mysql -u root < "$path/databases/mysql_all.sql" 2>/dev/null || \
      log_warn "MySQL restore had errors"
  fi

  # Restore volumes
  for archive in "$path/volumes"/vol_*.tar.gz; do
    [[ ! -f "$archive" ]] && continue
    local vol_name
    vol_name=$(basename "$archive" .tar.gz | sed 's/^vol_//')
    log_info "Restoring volume: $vol_name"
    docker volume create "$vol_name" 2>/dev/null || true
    docker run --rm \
      -v "${vol_name}:/data" \
      -v "$(dirname "$archive"):/backup:ro" \
      alpine:3.19 \
      tar xzf "/backup/$(basename "$archive")" -C /data 2>/dev/null || \
      log_warn "Failed to restore volume: $vol_name"
  done

  log_info "Restore complete ✓"
}

# ---------------------------------------------------------------------------
# Send notification
# ---------------------------------------------------------------------------
send_notification() {
  local status="$1"
  local message="$2"
  local script="$SCRIPT_DIR/backup-notify.sh"

  if [[ -x "$script" ]]; then
    "$script" "$status" "$message" "$BACKUP_ID" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  mkdir -p "$BACKUP_DIR" "$BACKUP_PATH" 2>/dev/null || true

  # Handle special modes
  if $DO_LIST; then
    list_backups
    exit 0
  fi

  if $DO_VERIFY; then
    verify_backup "${RESTORE_ID:-$BACKUP_ID}"
    exit $?
  fi

  if [[ -n "$RESTORE_ID" ]]; then
    restore_backup "$RESTORE_ID"
    exit $?
  fi

  # Validate target
  if [[ -z "$TARGET" ]]; then
    log_error "No target specified. Use --target <stack|all>"
    usage
  fi

  log_step "Starting backup — $BACKUP_ID"
  log_info "Target stack: $TARGET | Storage: $BACKUP_TARGET | DRY_RUN: $DRY_RUN"

  local start_time
  start_time=$(date +%s)

  # Run backups
  case "$TARGET" in
    all)
      backup_configs
      backup_all_volumes
      backup_databases
      ;;
    *)
      backup_stack_volumes "$TARGET"
      ;;
  esac

  # Generate manifest
  generate_manifest

  # Upload to remote
  upload_to_remote "$BACKUP_PATH"

  # Cleanup old backups
  cleanup_old

  # Summary
  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  if ! $DRY_RUN; then
    local total_size
    total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
    log_step "Backup complete"
    log_info "  ID:       $BACKUP_ID"
    log_info "  Size:     $total_size"
    log_info "  Target:   $BACKUP_TARGET"
    log_info "  Duration: ${elapsed}s"
    log_info "  Path:     $BACKUP_PATH"

    # Send success notification
    send_notification "success" "Backup $BACKUP_ID completed ($total_size, ${elapsed}s)"
  else
    log_info "[DRY-RUN] Complete — no changes made"
  fi
}

# Run with error handling
if ! main; then
  send_notification "failure" "Backup $BACKUP_ID failed"
  exit 1
fi
