EXPLANATION:
I updated the backup script to fully support all command-line arguments specified in the requirements like `--target`, `--dry-run`, `--restore`, `--list`, and `--verify`. I also added remote target syncing for S3, B2, SFTP, and local directories, plus ntfy notifications and better error handling.

CODE:
```bash
#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & DR — 自动备份 + 灾难恢复脚本
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
NTFY_URL="${NTFY_URL:-}"

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
  if [[ -n "$NTFY_URL" ]]; then
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "$NTFY_URL" >/dev/null || true
  fi
}

usage() {
  echo "用法: backup.sh --target [选项]"
  echo "选项:"
  echo "  --target all     备份所有 stack 数据卷"
  echo "  --target media   仅备份媒体栈"
  echo "  --dry-run        显示将备份的内容，不实际执行"
  echo "  --restore <id>   从指定备份恢复"
  echo "  --list           列出所有备份"
  echo "  --verify         验证备份完整性"
  exit 1
}

list_backups() {
  log_info "Available backups in $BACKUP_DIR:"
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d | sort | while read -r d; do
      echo "  - $(basename "$d") ($(du -sh "$d" | cut -f1))"
    done
  else
    log_warn "Backup directory does not exist: $BACKUP_DIR"
  fi
}

verify_backup() {
  local target_id="${1:-}"
  if [[ -z "$target_id" ]]; then
    # Find latest
    target_id=$(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d | sort | tail -n 1)
  else
    target_id="$BACKUP_DIR/$target_id"
  fi

  if [[ ! -d "$target_id" ]]; then
    log_error "Backup path not found: $target_id"
    exit 1
  fi

  log_info "Verifying backup: $target_id"
  local failed=0
  for f in "$target_id"/*.tar.gz; do
    if [[ -f "$f" ]]; then
      if ! tar tzf "$f" >/dev/null 2>&1; then
        log_error "Corrupted archive: $(basename "$f")"
        ((failed++))
      fi
    fi
  done

  if [[ $failed -eq 0 ]]; then
    log_info "Backup verification successful!"
  else
    log_error "Backup verification failed with $failed corrupted archives."
    exit 1
  fi
}

restore_backup() {
  local target_id="$1"
  local target_path