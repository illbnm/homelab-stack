EXPLANATION:
I updated the backup script to fully support all required command line arguments like target selection, dry-runs, restores, listing, and verification. I also added support for remote targets such as S3, B2, and SFTP alongside local paths, plus notifications via ntfy and proper error handling.

CODE:
```
#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Docker volumes + configs + databases comprehensive backup
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
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "$NTFY_URL" >/dev/null 2>&1 || true
  fi
}

usage() {
  cat <<EOF
用法: backup.sh --target [选项]
选项:
  --target all        备份所有 stack 数据卷和配置
  --target media      仅备份媒体栈数据卷
  --dry-run           显示将备份的内容，不实际执行
  --restore <path>    从指定备份恢复
  --list              列出所有备份
  --verify            验证备份完整性
EOF
  exit 1
}

# 备份 Docker volumes
backup_volumes() {
  local target_type="$1"
  log_info "Backing up Docker volumes (target: $target_type)..."
  local volumes
  if [[ "$target_type" == "media" ]]; then
    volumes=$(docker volume ls --format '{{.Name}}' | grep -E 'media|plex|jellyfin|sonarr|radarr|lidarr|qbittorrent' || true)
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
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
    local pg_pass