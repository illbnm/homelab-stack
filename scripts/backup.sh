#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 完整的备份与恢复脚本
# 支持：本地/S3/B2/SFTP/R2 多种备份目标，3-2-1 备份策略
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

# 加载环境变量
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# 默认配置
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*" >&2; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[backup]${NC} $*" || true; }

# 发送通知
send_notification() {
  local title="$1"
  local message="$2"
  local priority="${3:-3}"
  
  if command -v curl &> /dev/null; then
    curl -s -X POST \
      -H "Title: $title" \
      -H "Priority: $priority" \
      -d "$message" \
      "$NTFY_SERVER/$NTFY_TOPIC" > /dev/null 2>&1 || \
      log_warn "Failed to send notification"
  fi
}

# 显示帮助
show_help() {
  cat << EOF
用法: $(basename "$0") [选项]

备份 HomeLab 数据卷和配置文件，支持多种存储目标。

选项:
  --target <stack|all>    备份目标 (默认：all)
                          - all: 备份所有 stack 数据卷
                          - media: 仅备份媒体栈
                          - storage: 仅备份存储栈
                          - productivity: 仅备份生产力栈
  --dry-run               显示将备份的内容，不实际执行
  --restore <backup_id>   从指定备份恢复
  --list                  列出所有备份
  --verify                验证备份完整性
  --cleanup               清理过期备份
  --help, -h              显示此帮助信息

示例:
  $(basename "$0") --target all
  $(basename "$0") --target media --dry-run
  $(basename "$0") --list
  $(basename "$0") --restore 20260318_020000
  $(basename "$0") --verify

环境变量:
  BACKUP_TARGET          备份目标 (local|s3|b2|sftp|r2)
  BACKUP_DIR             本地备份目录
  RESTIC_REPOSITORY      Restic 仓库路径
  RESTIC_PASSWORD        Restic 仓库密码
  BACKUP_RETENTION_DAYS  备份保留天数
  NTFY_TOPIC             Ntfy 通知主题
  NTFY_SERVER            Ntfy 服务器地址

EOF
}

# 获取 Restic 仓库配置
get_restic_config() {
  case "$BACKUP_TARGET" in
    local)
      export RESTIC_REPOSITORY="${BACKUP_DIR}/restic"
      ;;
    s3|r2)
      export RESTIC_REPOSITORY="s3:${BACKUP_S3_URL:-s3://homelab-backups}"
      export AWS_ACCESS_KEY_ID="${BACKUP_S3_ACCESS_KEY:-}"
      export AWS_SECRET_ACCESS_KEY="${BACKUP_S3_SECRET_KEY:-}"
      ;;
    b2)
      export RESTIC_REPOSITORY="b2:${BACKUP_B2_BUCKET:-}:${BACKUP_B2_PATH:-/}"
      export B2_ACCOUNT_ID="${BACKUP_B2_ACCOUNT_ID:-}"
      export B2_ACCOUNT_KEY="${BACKUP_B2_APPLICATION_KEY:-}"
      ;;
    sftp)
      export RESTIC_REPOSITORY="sftp:${BACKUP_SFTP_USER:-}@${BACKUP_SFTP_HOST:-}:${BACKUP_SFTP_PATH:-/}"
      export RESTIC_SFTP_PASSWORD="${BACKUP_SFTP_PASSWORD:-}"
      ;;
    *)
      log_error "Unknown backup target: $BACKUP_TARGET"
      exit 1
      ;;
  esac
  
  if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
    log_error "RESTIC_PASSWORD is not set"
    exit 1
  fi
  export RESTIC_PASSWORD
}

# 列出所有备份
list_backups() {
  log_info "Listing all backups..."
  
  get_restic_config
  
  if command -v restic &> /dev/null; then
    restic snapshots 2>/dev/null || log_warn "No snapshots found"
  else
    log_warn "restic not installed, listing local backups..."
    if [[ -d "$BACKUP_DIR" ]]; then
      ls -lht "$BACKUP_DIR" | head -20
    else
      log_warn "Backup directory not found: $BACKUP_DIR"
    fi
  fi
}

# 验证备份完整性
verify_backups() {
  log_info "Verifying backup integrity..."
  
  get_restic_config
  
  if command -v restic &> /dev/null; then
    restic check 2>&1 || {
      log_error "Backup verification failed"
      send_notification "❌ Backup Verification Failed" "Backup integrity check failed" 5
      exit 1
    }
    log_info "Backup verification passed"
    send_notification "✅ Backup Verification Passed" "All backups are intact" 3
  else
    log_warn "restic not installed, skipping verification"
  fi
}

# 清理过期备份
cleanup_old_backups() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  
  get_restic_config
  
  if command -v restic &> /dev/null; then
    restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 2>&1 || \
      log_warn "Cleanup failed"
  else
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
  fi
  
  log_info "Cleanup complete"
}

# 备份 Docker volumes
backup_volumes() {
  local target="$1"
  local dry_run="${2:-false}"
  
  log_info "Backing up Docker volumes (target: $target)..."
  
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  
  local count=0
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    
    # 根据 target 过滤
    case "$target" in
      media)
        [[ ! "$vol" =~ ^(jellyfin|sonarr|radarr|prowlarr|qbittorrent) ]] && continue
        ;;
      storage)
        [[ ! "$vol" =~ ^(nextcloud|minio|filebrowser) ]] && continue
        ;;
      productivity)
        [[ ! "$vol" =~ ^(gitea|vaultwarden|outline|bookstack) ]] && continue
        ;;
    esac
    
    if [[ "$dry_run" == "true" ]]; then
      log_info "  [DRY-RUN] Would backup volume: $vol"
    else
      log_info "  Volume: $vol"
      local backup_file="$BACKUP_PATH/vol_${vol}.tar.gz"
      docker run --rm \
        -v "${vol}:/data:ro" \
        -v "$BACKUP_PATH:/backup" \
        alpine:3.19 \
        tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null && \
        ((count++)) || \
        log_warn "  Failed to backup volume: $vol"
    fi
  done <<< "$volumes"
  
  log_info "Backed up $count volumes"
}

# 备份配置文件
backup_configs() {
  local dry_run="${1:-false}"
  
  log_info "Backing up configs..."
  
  if [[ "$dry_run" == "true" ]]; then
    log_info "  [DRY-RUN] Would backup: config/, stacks/, scripts/"
  else
    tar czf "$BACKUP_PATH/configs.tar.gz" \
      -C "$BASE_DIR" \
      --exclude='stacks/*/data' \
      --exclude='stacks/*/volumes' \
      config/ stacks/ scripts/ 2>/dev/null && \
      log_info "  Configs backed up" || \
      log_warn "  Config backup failed"
  fi
}

# 备份数据库
backup_databases() {
  local dry_run="${1:-false}"
  
  log_info "Backing up databases..."
  
  # PostgreSQL
  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      log_info "  [DRY-RUN] Would backup PostgreSQL from $pg_container"
    else
      local pg_pass
      pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
      docker exec "$pg_container" \
        sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
        > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null && \
        log_info "  PostgreSQL backed up" || \
        log_warn "  PostgreSQL backup failed"
    fi
  fi
  
  # MariaDB/MySQL
  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      log_info "  [DRY-RUN] Would backup MySQL from $mysql_container"
    else
      local mysql_pass
      mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
      docker exec "$mysql_container" \
        sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
        > "$BACKUP_PATH/mysql_all.sql" 2>/dev/null && \
        log_info "  MySQL backed up" || \
        log_warn "  MySQL backup failed"
    fi
  fi
  
  # Redis (RDB snapshot)
  local redis_container
  redis_container=$(docker ps --format '{{.Names}}' | grep -E 'redis' | head -1 || true)
  if [[ -n "$redis_container" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      log_info "  [DRY-RUN] Would backup Redis from $redis_container"
    else
      docker exec "$redis_container" redis-cli BGSAVE 2>/dev/null || true
      sleep 2
      docker cp "$redis_container:/data/dump.rdb" "$BACKUP_PATH/redis_dump.rdb" 2>/dev/null && \
        log_info "  Redis backed up" || \
        log_warn "  Redis backup failed (may not have persistence enabled)"
    fi
  fi
}

# 使用 Restic 备份
backup_with_restic() {
  local dry_run="${1:-false}"
  
  get_restic_config
  
  if ! command -v restic &> /dev/null; then
    log_warn "restic not installed, using tar backup"
    return 1
  fi
  
  log_info "Initializing restic repository..."
  restic init 2>/dev/null || true
  
  log_info "Creating restic snapshot..."
  if [[ "$dry_run" == "true" ]]; then
    log_info "  [DRY-RUN] Would create snapshot of $BACKUP_PATH"
  else
    restic backup "$BACKUP_PATH" 2>&1 || {
      log_error "Restic backup failed"
      send_notification "❌ Backup Failed" "Restic backup failed" 5
      return 1
    }
  fi
  
  return 0
}

# 恢复备份
restore_backup() {
  local backup_id="$1"
  
  log_info "Restoring from backup: $backup_id"
  
  get_restic_config
  
  if command -v restic &> /dev/null; then
    # 使用 restic 恢复
    local restore_path="/tmp/homelab-restore-$$"
    mkdir -p "$restore_path"
    
    restic restore "$backup_id" --target "$restore_path" 2>&1 || {
      log_error "Restore failed"
      send_notification "❌ Restore Failed" "Failed to restore from $backup_id" 5
      exit 1
    }
    
    log_info "Restore complete to: $restore_path"
    log_info "Manual steps required:"
    log_info "  1. Review restored files in $restore_path"
    log_info "  2. Copy configs back to $BASE_DIR"
    log_info "  3. Restore Docker volumes using docker run --rm -v <vol>:/data -v $restore_path:/backup alpine tar xzf /backup/vol_*.tar.gz -C /data"
  else
    log_error "restic not installed, cannot restore"
    exit 1
  fi
}

# 生成备份摘要
generate_summary() {
  if [[ -d "$BACKUP_PATH" ]]; then
    local total_size
    total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
    log_info "Backup complete: $BACKUP_PATH ($total_size)"
    ls -lh "$BACKUP_PATH/"
    
    send_notification "✅ Backup Complete" "Backup: $TIMESTAMP, Size: $total_size, Target: $BACKUP_TARGET" 3
  fi
}

# 主备份流程
do_backup() {
  local target="${1:-all}"
  local dry_run="${2:-false}"
  
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
  
  if [[ "$dry_run" == "true" ]]; then
    log_info "=== DRY RUN MODE ==="
    log_info "Would create backup at: $BACKUP_PATH"
    log_info "Target: $target"
    log_info "Backup target: $BACKUP_TARGET"
  else
    mkdir -p "$BACKUP_PATH"
    log_info "Starting backup — $TIMESTAMP"
    send_notification "🔄 Backup Started" "Starting backup: $TIMESTAMP" 3
  fi
  
  backup_configs "$dry_run"
  backup_volumes "$target" "$dry_run"
  backup_databases "$dry_run"
  
  if [[ "$dry_run" != "true" ]]; then
    # 尝试使用 restic
    if ! backup_with_restic "$dry_run"; then
      # Fallback to tar
      log_info "Creating tar archive..."
      tar czf "$BACKUP_DIR/${TIMESTAMP}.tar.gz" -C "$BACKUP_DIR" "$TIMESTAMP" 2>/dev/null || true
      rm -rf "$BACKUP_PATH"
    fi
    
    cleanup_old_backups
    generate_summary
  fi
}

# 解析参数
TARGET="all"
DRY_RUN="false"
RESTORE_ID=""
LIST_MODE="false"
VERIFY_MODE="false"
CLEANUP_MODE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --restore)
      RESTORE_ID="$2"
      shift 2
      ;;
    --list)
      LIST_MODE="true"
      shift
      ;;
    --verify)
      VERIFY_MODE="true"
      shift
      ;;
    --cleanup)
      CLEANUP_MODE="true"
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# 执行操作
if [[ "$LIST_MODE" == "true" ]]; then
  list_backups
elif [[ "$VERIFY_MODE" == "true" ]]; then
  verify_backups
elif [[ "$CLEANUP_MODE" == "true" ]]; then
  cleanup_old_backups
elif [[ -n "$RESTORE_ID" ]]; then
  restore_backup "$RESTORE_ID"
else
  do_backup "$TARGET" "$DRY_RUN"
fi
