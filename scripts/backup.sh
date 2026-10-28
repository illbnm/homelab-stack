EXPLANATION:
I updated the backup script to fully implement all required CLI flags like `--target`, `--dry-run`, `--restore`, `--list`, and `--verify`. I also added support for pushing backups to remote targets like S3, B2, and SFTP, integrated ntfy notifications for status updates, and wrote out the corresponding disaster recovery guide and crontab automation setup.

CODE:
```
#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Docker volumes + configs 全量备份及灾难恢复工具
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

BACKUP_TARGET="${BACKUP_TARGET:-local}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

send_notification() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  if [[ -n "$NTFY_TOPIC" ]]; then
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null || true
  fi
}

usage() {
  echo "用法: backup.sh --target [选项]"
  echo "选项:"
  echo "  --target all       备份所有 stack 数据卷"
  echo "  --target media     仅备份媒体栈"
  echo "  --dry-run          显示将备份的内容，不实际执行"
  echo "  --restore <path>   从指定备份恢复"
  echo "  --list             列出所有备份"
  echo "  --verify           验证备份完整性"
  exit 1
}

list_backups() {
  log_info "现有备份列表 ($BACKUP_DIR):"
  if [[ -d "$BACKUP_DIR" ]]; then
    ls -lh "$BACKUP_DIR" | grep '^d' || echo "无本地备份目录"
  else
    echo "备份目录不存在"
  fi
}

verify_backup() {
  local target_path="${1:-}"
  if [[ -z "$target_path" ]]; then
    target_path=$(find "$BACKUP_DIR" -maxdepth 1 -type d | sort | tail -n 1)
  fi
  log_info "正在验证备份完整性: $target_path"
  if [[ ! -d "$target_path" ]]; then
    log_error "备份路径不存在: $target_path"
    exit 1
  fi
  for f in "$target_path"/*.tar.gz; do
    if [[ -f "$f" ]]; then
      if gzip -t "$f" 2>/dev/null; then
        log_info "  [OK] $(basename "$f")"
      else
        log_error "  [ERROR] 损坏的归档文件: $(basename "$f")"
        exit 1
      fi
    fi
  done
  log_info "备份验证通过！"
}

restore_backup() {
  local restore_path="$1"
  log_warn "开始从 $restore_path 恢复数据..."
  if [[ ! -d "$restore_path" ]]; then
    log_error "恢复路径不存在: $restore_path"
    exit 1
  fi

  # 恢复配置文件
  if [[ -f