EXPLANATION:
I updated the backup script to fully support all command line flags specified in the issue requirements like `--target`, `--dry-run`, `--restore`, `--list`, and `--verify`. I also added ntfy notification hooks and target syncing capabilities so it integrates nicely with S3, B2, SFTP, and local storage configurations.

CODE:
```
#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Docker volumes + configs 完整备份与灾难恢复方案
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

send_notification() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  if [[ -n "$NTFY_TOPIC" ]]; then
    curl -s \
      -H "Title: $title" \
      -H "Priority: $priority" \
      -d "$message" \
      "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1 || true
  fi
}

usage() {
  echo "用法: backup.sh --target [选项]"
  echo "选项:"
  echo "  --target all        备份所有 stack 数据卷和配置"
  echo "  --target media      仅备份媒体栈"
  echo "  --dry-run           显示将备份的内容，不实际执行"
  echo "  --restore <ID>      从指定备份恢复"
  echo "  --list              列出所有备份"
  echo "  --verify            验证备份完整性"
  exit 1
}

list_backups() {
  log_info "现有备份列表 ($BACKUP_DIR):"
  if [[ -d "$BACKUP_DIR" ]]; then
    ls -lh "$BACKUP_DIR"
  else
    log_warn "备份目录不存在: $BACKUP_DIR"
  fi
}

verify_backups() {
  log_info "验证备份完整性..."
  local errors=0
  for dir in "$BACKUP_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    log_info "检查目录: $(basename "$dir")"
    if [[ -f "${dir}configs.tar.gz" ]]; then
      if ! tar -tzf "${dir}configs.tar.gz" >/dev/null 2>&1; then
        log_error "损坏的配置文件压缩包: ${dir}configs.tar.gz"
        ((errors++))
      fi
    fi
  done
  if [[ $errors -eq 0 ]]; then
    log_info "所有检查通过，备份完整性正常。"
  else
    log_error "发现 $errors 个损坏的备份文件！"
    exit 1
  fi
}

restore_backup() {
  local target_id="$1"
  local target_path="$BACKUP_DIR/$target_id"
  if [[ ! -d "$target_path" ]]; then
    log_error "指定的备份不存在: $target_path"
    exit 1
  fi
  log_warn "开始从备份恢复: $target_id"
  
  if [[ -f "$target_path/configs.tar.gz" ]];