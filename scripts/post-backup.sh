#!/usr/bin/env bash
# =============================================================================
# Resticker Post-Backup Hook
# 执行时机: Restic 备份后
# 用途: 发送通知、清理临时文件、同步到云存储
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load env
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env"

log() {
  echo "[post-backup] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

send_ntfy() {
  local message="$1"
  local topic="${NTFY_TOPIC:-homelab-backups}"

  curl -s -X POST "https://ntfy.sh/$topic" \
    -d "[$(hostname)] $message" \
    --no-progress-meter 2>/dev/null || true
}

log "开始后备份处理..."

# Get backup stats
if [[ -n "${RESTIC_PASSWORD:-}" ]] && command -v restic &> /dev/null; then
  local repo="${RESTIC_REPO_PATH:-/opt/homelab-backups/restic}"
  local snapshot_count=$(restic snapshots --repo "$repo" --password "$RESTIC_PASSWORD" 2>/dev/null | grep -c "^snapshot" || echo "0")
  local repo_size=$(restic stats --repo "$repo" --password "$RESTIC_PASSWORD" 2>/dev/null | grep "Total size" | awk '{print $NF}' || echo "unknown")

  log "Restic 统计: $snapshot_count 个快照, 大小: $repo_size"
  send_ntfy "✅ Restic 备份完成: $snapshot_count 快照 ($repo_size)"
fi

# Rclone sync to cloud (if configured)
if [[ -n "${RCLONE_DESTINATION:-}" ]] && [[ -f "${RCLONE_CONFIG_PATH:-$BASE_DIR/config/rclone/rclone.conf}" ]]; then
  log "同步到云存储..."
  local backup_dir="${BACKUP_LOCAL_PATH:-/opt/homelab-backups}"

  docker run --rm \
    -v "$backup_dir:/data:ro" \
    -v "${RCLONE_CONFIG_PATH:-$BASE_DIR/config/rclone/rclone.conf}:/config/rclone.conf:ro" \
    rclone/rclone:1.68.0 \
    sync /data "${RCLONE_DESTINATION}:/homelab-backups/$(hostname)" \
    --config /config/rclone.conf \
    --transfers 4 \
    --checkers 8 \
    --drive-chunk-size 64M \
    --quiet 2>/dev/null && {
    log "云存储同步完成"
    send_ntfy "✅ 云存储同步完成"
  } || {
    log_warn "云存储同步失败"
    send_ntfy "⚠️ 云存储同步失败"
  }
fi

# Cleanup temp files
log "清理临时文件..."
find /tmp -name "homelab-backup-*" -mmin +60 -delete 2>/dev/null || true

log "后备份处理完成"
