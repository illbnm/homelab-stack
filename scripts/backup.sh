#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 3-2-1 备份策略 (本地 + 云存储)
# 支持：Local, S3, Backblaze B2, SFTP, Cloudflare R2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# 备份配置
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"  # local|s3|b2|sftp|r2
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
RESTIC_REPO="${RESTIC_REPO:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"

# 云存储配置
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
S3_BUCKET="${S3_BUCKET:-}"

B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
B2_APPLICATION_KEY="${B2_APPLICATION_KEY:-}"
B2_BUCKET="${B2_BUCKET:-}"

SFTP_HOST="${SFTP_HOST:-}"
SFTP_USER="${SFTP_USER:-}"
SFTP_PORT="${SFTP_PORT:-22}"
SFTP_PATH="${SFTP_PATH:-/backups}"

R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
R2_BUCKET="${R2_BUCKET:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

# 发送通知
send_notification() {
  local title="$1"
  local message="$2"
  local priority="${3:-3}"
  
  if command -v "$SCRIPT_DIR/notify.sh" &>/dev/null; then
    "$SCRIPT_DIR/notify.sh" "homelab-backup" "$title" "$message" "$priority" || true
  fi
}

mkdir -p "$BACKUP_PATH"

# 初始化 Restic 仓库
init_restic() {
  if [[ -z "$RESTIC_REPO" || -z "$RESTIC_PASSWORD" ]]; then
    log_warn "Restic not configured, skipping..."
    return 0
  fi
  
  log_info "Initializing Restic repository..."
  export RESTIC_PASSWORD
  restic init --repo "$RESTIC_REPO" 2>/dev/null || log_info "Repository already exists"
}

# Restic 备份
restic_backup() {
  if [[ -z "$RESTIC_REPO" || -z "$RESTIC_PASSWORD" ]]; then
    return 0
  fi
  
  log_info "Running Restic backup..."
  export RESTIC_PASSWORD
  restic backup --repo "$RESTIC_REPO" "$BACKUP_PATH" \
    --exclude='*.tmp' \
    --exclude='cache/*' \
    --tag "homelab" \
    --tag "timestamp=$TIMESTAMP" || log_error "Restic backup failed"
}

# 上传到 S3 兼容存储 (S3/R2)
upload_s3() {
  local bucket="$1"
  local access_key="$2"
  local secret_key="$3"
  local endpoint="${4:-}"
  
  log_info "Uploading to S3 bucket: $bucket..."
  
  export AWS_ACCESS_KEY_ID="$access_key"
  export AWS_SECRET_ACCESS_KEY="$secret_key"
  
  if [[ -n "$endpoint" ]]; then
    export AWS_ENDPOINT_URL="$endpoint"
  fi
  
  aws s3 sync "$BACKUP_PATH" "s3://$bucket/homelab/$TIMESTAMP" \
    --quiet || log_error "S3 upload failed"
}

# 上传到 Backblaze B2
upload_b2() {
  local account_id="$1"
  local application_key="$2"
  local bucket="$3"
  
  log_info "Uploading to Backblaze B2: $bucket..."
  
  b2 authorize-account "$account_id" "$application_key" || log_error "B2 auth failed"
  b2 sync "$BACKUP_PATH" "b2://$bucket/homelab/$TIMESTAMP" || log_error "B2 upload failed"
}

# 上传到 SFTP
upload_sftp() {
  local host="$1"
  local user="$2"
  local port="$3"
  local path="$4"
  
  log_info "Uploading to SFTP: $user@$host:$port$path..."
  
  rsync -avz -e "ssh -p $port -o StrictHostKeyChecking=no" \
    "$BACKUP_PATH/" "$user@$host:$path/" || log_error "SFTP upload failed"
}

# 备份 Docker volumes
backup_volumes() {
  log_info "Backing up Docker volumes..."
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
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

# 备份配置文件
backup_configs() {
  log_info "Backing up configs..."
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    config/ stacks/ scripts/ 2>/dev/null || true
}

# 备份数据库
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
}

# 清理旧备份
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# 生成备份摘要
generate_summary() {
  local total_size
  total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
  log_info "Backup complete: $BACKUP_PATH ($total_size)"
  ls -lh "$BACKUP_PATH/"
}

# 列出备份
list_backups() {
  log_info "Available backups:"
  ls -lhd "$BACKUP_DIR"/*/ 2>/dev/null | tail -20
}

# 验证备份
verify_backup() {
  local backup_path="$1"
  log_info "Verifying backup: $backup_path..."
  
  if [[ -d "$backup_path" ]]; then
    tar -tzf "$backup_path/configs.tar.gz" &>/dev/null && log_info "✓ Config archive OK" || log_error "✗ Config archive corrupted"
    log_info "Backup files:"
    ls -lh "$backup_path/"
  else
    log_error "Backup not found: $backup_path"
    return 1
  fi
}

# 恢复备份
restore_backup() {
  local backup_path="$1"
  local target="${2:-$BASE_DIR}"
  
  if [[ ! -d "$backup_path" ]]; then
    log_error "Backup not found: $backup_path"
    return 1
  fi
  
  log_info "Restoring from: $backup_path"
  log_warn "This will overwrite files in $target"
  read -p "Continue? (y/N): " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
  
  tar xzf "$backup_path/configs.tar.gz" -C "$target" || log_error "Restore failed"
  log_info "Restore complete. Restart services to apply."
}

# 显示帮助
show_help() {
  cat << EOF
HomeLab Backup — 3-2-1 备份策略

用法:
  $0 [选项]

选项:
  --target <type>     备份目标：local|s3|b2|sftp|r2 (默认：local)
  --list              列出所有备份
  --verify <path>     验证备份完整性
  --restore <path>    从备份恢复
  --dry-run           显示将要备份的内容，不实际执行
  --help              显示帮助

环境变量:
  BACKUP_TARGET       备份目标类型
  BACKUP_DIR          本地备份目录
  RESTIC_REPO         Restic 仓库路径
  RESTIC_PASSWORD     Restic 密码
  S3_BUCKET           S3 存储桶名称
  B2_BUCKET           Backblaze B2 存储桶
  SFTP_HOST           SFTP 服务器地址
  SFTP_USER           SFTP 用户名

示例:
  $0                          # 本地备份
  $0 --target s3              # 备份到 S3
  $0 --list                   # 列出备份
  $0 --verify /path/to/backup # 验证备份
  $0 --restore /path/to/backup # 恢复备份

EOF
}

# 解析参数
DRY_RUN=false
ACTION="backup"
RESTORE_PATH=""
VERIFY_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      BACKUP_TARGET="$2"
      shift 2
      ;;
    --list)
      ACTION="list"
      shift
      ;;
    --verify)
      ACTION="verify"
      VERIFY_PATH="$2"
      shift 2
      ;;
    --restore)
      ACTION="restore"
      RESTORE_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
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

# 执行动作
case $ACTION in
  list)
    list_backups
    exit 0
    ;;
  verify)
    verify_backup "${VERIFY_PATH:-$BACKUP_PATH}"
    exit $?
    ;;
  restore)
    restore_backup "$RESTORE_PATH"
    exit $?
    ;;
  backup)
    ;;
  *)
    log_error "Unknown action: $ACTION"
    exit 1
    ;;
esac

# 干运行模式
if [[ "$DRY_RUN" == true ]]; then
  log_info "Dry run — showing what would be backed up:"
  log_info "  Configs: config/ stacks/ scripts/"
  log_info "  Volumes: $(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' | wc -l) volumes"
  log_info "  Target: $BACKUP_TARGET"
  exit 0
fi

# 开始备份
log_info "Starting backup — $TIMESTAMP"
log_info "Target: $BACKUP_TARGET"

send_notification "🔄 备份开始" "HomeLab 备份任务已启动"

backup_configs
backup_volumes
backup_databases

# 上传到云存储
case "$BACKUP_TARGET" in
  s3)
    [[ -n "$S3_BUCKET" ]] && upload_s3 "$S3_BUCKET" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
    ;;
  b2)
    [[ -n "$B2_BUCKET" ]] && upload_b2 "$B2_ACCOUNT_ID" "$B2_APPLICATION_KEY" "$B2_BUCKET"
    ;;
  sftp)
    [[ -n "$SFTP_HOST" ]] && upload_sftp "$SFTP_HOST" "$SFTP_USER" "$SFTP_PORT" "$SFTP_PATH"
    ;;
  r2)
    [[ -n "$R2_BUCKET" ]] && upload_s3 "$R2_BUCKET" "$R2_ACCESS_KEY_ID" "$R2_SECRET_ACCESS_KEY" "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    ;;
  local|*)
    log_info "Local backup only"
    ;;
esac

# Restic 备份
init_restic
restic_backup

cleanup_old
generate_summary

send_notification "✅ 备份完成" "HomeLab 备份成功完成：$BACKUP_PATH"
