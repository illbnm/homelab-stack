EXPLANATION:
I updated the backup script to fully support all command-line flags required by the bounty spec like target selection, dry run, restore, listing, and integrity verification. I also hooked up multi-backend syncing for destinations like S3, B2, and SFTP, added automatic ntfy notifications, and created the disaster recovery playbook.

CODE:
```
#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & DR — 完整备份与灾难恢复脚本
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

# 备份目标与通知配置
BACKUP_TARGET="${BACKUP_TARGET:-local}" # local | s3 | b2 | sftp
NTFY_URL="${NTFY_URL:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

notify() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  if [[ -n "$NTFY_URL" ]]; then
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "$NTFY_URL" >/dev/null || true
  fi
}

usage() {
  echo "用法: $(basename "$0") --target [选项]"
  echo "选项:"
  echo "  --target all        备份所有 stack 数据卷与配置"
  echo "  --target media      仅备份媒体栈数据卷"
  echo "  --dry-run           显示将备份的内容，不实际执行"
  echo "  --restore <path>    从指定备份恢复"
  echo "  --list              列出所有本地及远程备份"
  echo "  --verify            验证备份完整性"
  exit 1
}

# 备份 Docker volumes
backup_volumes() {
  local target_type="$1"
  log_info "Backing up Docker volumes (target: $target_type)..."
  local volumes
  if [[ "$target_type" == "media" ]]; then
    volumes=$(docker volume ls --format '{{.Name}}' | grep -E 'media|plex|jellyfin|qbittorrent|transmission' || true)
  else
    volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
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