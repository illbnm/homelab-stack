#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script — Docker volumes + configs 全量备份
# =============================================================================
# Usage:
#   backup.sh --target <stack|all> [options]
#
# Options:
#   --target all          备份所有 stack 数据卷
#   --target <stack>     仅备份指定 stack (e.g., media, databases)
#   --dry-run             显示将备份的内容，不实际执行
#   --restore <backup_id> 从指定备份恢复
#   --list                列出所有备份
#   --verify              验证备份完整性
#
# Examples:
#   ./backup.sh --target all              # 备份所有
#   ./backup.sh --target media --dry-run  # 试运行备份媒体栈
#   ./backup.sh --list                    # 列出备份
#   ./backup.sh --verify                  # 验证备份
#   ./backup.sh --restore 20260318_020000 # 恢复指定备份
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

# Load environment
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Defaults
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_TARGET="${BACKUP_TARGET:-local}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*"; }
log_step()  { echo -e "${BLUE}[backup]${NC} $*"; }

# Parse arguments
TARGET="all"
DRY_RUN=false
RESTORE_ID=""
LIST=false
VERIFY_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --restore)
      RESTORE_ID="$2"
      shift 2
      ;;
    --list)
      LIST=true
      shift
      ;;
    --verify)
      VERIFY_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# ======================== List Backups ========================
list_backups() {
  log_info "Available backups in $BACKUP_DIR:"
  echo ""
  if [[ -d "$BACKUP_DIR" ]]; then
    ls -1t "$BACKUP_DIR/" | while read -r dir; do
      local size
      size=$(du -sh "$BACKUP_DIR/$dir" 2>/dev/null | cut -f1 || echo "unknown")
      echo "  - $dir ($size)"
    done
  else
    echo "  No backups found"
  fi
}

# ======================== Verify Backups ========================
verify_backups() {
  log_info "Verifying backup integrity..."
  
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backup directory found"
    return 1
  fi
  
  local failed=0
  for backup in "$BACKUP_DIR"/*/; do
    [[ ! -d "$backup" ]] && continue
    local name
    name=$(basename "$backup")
    log_step "Verifying: $name"
    
    # Check for expected files
    if [[ -f "$backup/configs.tar.gz" ]]; then
      if tar -tzf "$backup/configs.tar.gz" >/dev/null 2>&1; then
        log_info "  ✓ configs.tar.gz OK"
      else
        log_error "  ✗ configs.tar.gz CORRUPTED"
        ((failed++))
      fi
    fi
    
    # Check volumes
    for vol_backup in "$backup"/vol_*.tar.gz; do
      [[ ! -f "$vol_backup" ]] && continue
      if tar -tzf "$vol_backup" >/dev/null 2>&1; then
        log_info "  ✓ $(basename "$vol_backup") OK"
      else
        log_error "  ✗ $(basename "$vol_backup") CORRUPTED"
        ((failed++))
      fi
    done
  done
  
  if [[ $failed -eq 0 ]]; then
    log_info "All backups verified successfully!"
  else
    log_error "$failed backup(s) failed verification"
  fi
  
  return $failed
}

# ======================== Restore Backup ========================
restore_backup() {
  local backup_id="$1"
  local backup_path="$BACKUP_DIR/$backup_id"
  
  if [[ ! -d "$backup_path" ]]; then
    log_error "Backup not found: $backup_id"
    log_info "Available backups:"
    list_backups
    return 1
  fi
  
  log_info "Restoring from backup: $backup_id"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would restore:"
    ls -la "$backup_path/"
    return 0
  fi
  
  # Restore configs
  if [[ -f "$backup_path/configs.tar.gz" ]]; then
    log_info "Restoring configurations..."
    tar -xzf "$backup_path/configs.tar.gz" -C "$BASE_DIR"
  fi
  
  # Restore databases
  if [[ -f "$backup_path/postgresql_all.sql" ]]; then
    log_info "Restoring PostgreSQL..."
    if docker ps --format '{{.Names}}' | grep -q postgres; then
      docker exec -i "$(docker ps --format '{{.Names}}' | grep postgres | head -1)" \
        psql -U postgres < "$backup_path/postgresql_all.sql" || \
        log_warn "PostgreSQL restore failed"
    fi
  fi
  
  if [[ -f "$backup_path/mysql_all.sql" ]]; then
    log_info "Restoring MariaDB..."
    if docker ps --format '{{.Names}}' | grep -q mariadb; then
      docker exec -i "$(docker ps --format '{{.Names}}' | grep mariadb | head -1)" \
        mysql -u root -p"${MARIADB_ROOT_PASSWORD:-}" < "$backup_path/mysql_all.sql" || \
        log_warn "MariaDB restore failed"
    fi
  fi
  
  log_info "Restore complete: $backup_id"
}

# ======================== Backup Docker Volumes ========================
backup_volumes() {
  local target_stack="$1"
  log_info "Backing up Docker volumes (target: $target_stack)..."
  
  # Get volumes based on target
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  
  # Filter by stack if specified
  if [[ "$target_stack" != "all" ]]; then
    volumes=$(echo "$volumes" | grep -E "^homelab[_-]$target_stack" || true)
  fi
  
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    
    if [[ "$DRY_RUN" == "true" ]]; then
      continue
    fi
    
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# ======================== Backup Configs ========================
backup_configs() {
  log_info "Backing up configs..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would backup: config/, stacks/, scripts/"
    return
  fi
  
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    config/ stacks/ scripts/ docs/ 2>/dev/null || true
}

# ======================== Backup Databases ========================
backup_databases() {
  log_info "Backing up databases..."

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'postgres\|postgresql'; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
    
    if [[ "$DRY_RUN" != "true" ]]; then
      docker exec "$pg_container" \
        sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
        > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null || \
        log_warn "PostgreSQL backup failed"
    else
      log_info "  [DRY RUN] Would backup PostgreSQL"
    fi
  fi

  # MariaDB/MySQL
  if docker ps --format '{{.Names}}' | grep -q 'mariadb\|mysql'; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
    
    if [[ "$DRY_RUN" != "true" ]]; then
      docker exec "$mysql_container" \
        sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
        > "$BACKUP_PATH/mysql_all.sql" 2>/dev/null || \
        log_warn "MySQL backup failed"
    else
      log_info "  [DRY RUN] Would backup MariaDB"
    fi
  fi
  
  # Redis
  if docker ps --format '{{.Names}}' | grep -q 'redis'; then
    local redis_container
    redis_container=$(docker ps --format '{{.Names}}' | grep redis | head -1)
    
    if [[ "$DRY_RUN" != "true" ]]; then
      docker exec "$redis_container" redis-cli BGSAVE 2>/dev/null || true
      sleep 2
      docker cp "$redis_container":/data/dump.rdb "$BACKUP_PATH/redis_dump.rdb" 2>/dev/null || \
        log_warn "Redis backup failed"
    else
      log_info "  [DRY RUN] Would backup Redis"
    fi
  fi
}

# ======================== Cleanup Old Backups ========================
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would delete backups older than $RETENTION_DAYS days"
    return
  fi
  
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# ======================== Generate Summary ========================
generate_summary() {
  local total_size
  total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
  log_info "Backup complete: $BACKUP_PATH ($total_size)"
  
  if [[ "$DRY_RUN" != "true" ]]; then
    ls -lh "$BACKUP_PATH/"
  fi
}

# ======================== Send Notification ========================
send_notification() {
  local status="$1"  # success or failure
  
  if [[ -z "${NTFY_URL:-}" ]]; then
    return
  fi
  
  local title
  local message
  
  if [[ "$status" == "success" ]]; then
    title="✅ Backup Complete"
    message="Backup $TIMESTAMP completed successfully"
  else
    title="❌ Backup Failed"
    message="Backup $TIMESTAMP failed"
  fi
  
  curl -s -X POST "$NTFY_URL" \
    -H "Title: $title" \
    -H "Priority: urgent" \
    -d "$message" 2>/dev/null || true
}

# ======================== Main ========================
main() {
  # Handle special modes first
  if [[ "$LIST" == "true" ]]; then
    list_backups
    exit 0
  fi
  
  if [[ "$VERIFY_ONLY" == "true" ]]; then
    verify_backups
    exit $?
  fi
  
  if [[ -n "$RESTORE_ID" ]]; then
    restore_backup "$RESTORE_ID"
    exit $?
  fi
  
  # Normal backup mode
  local backup_name="${TARGET}_${TIMESTAMP}"
  export BACKUP_PATH="$BACKUP_DIR/$backup_name"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would create backup: $backup_name"
  else
    mkdir -p "$BACKUP_PATH"
  fi
  
  log_info "Starting backup — $TARGET (dry-run: $DRY_RUN)"
  
  # Run backup steps
  backup_configs
  backup_volumes "$TARGET"
  backup_databases
  
  if [[ "$DRY_RUN" != "true" ]]; then
    cleanup_old
    generate_summary
    send_notification "success"
  else
    log_info "[DRY RUN] Backup would complete here"
  fi
}

# Run main
main
