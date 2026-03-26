#!/usr/bin/env bash
# =============================================================================
# Resticker Pre-Backup Hook
# 执行时机: Restic 备份前
# 用途: 确保数据库一致性（创建快照前刷盘）
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load env
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env"

log() {
  echo "[pre-backup] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log "开始预备份检查..."

# Flush PostgreSQL WAL
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'homelab-postgres'; then
  log "PostgreSQL: 检查点..."
  docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" \
    -c "CHECKPOINT;" 2>/dev/null || true
fi

# Flush MariaDB
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'homelab-mariadb'; then
  log "MariaDB: 刷新表..."
  docker exec homelab-mariadb mariadb -u root \
    -p"${MARIADB_ROOT_PASSWORD:-}" -e "FLUSH TABLES;" 2>/dev/null || true
fi

# Redis BGSAVE
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'homelab-redis'; then
  log "Redis: 触发 BGSAVE..."
  docker exec homelab-redis redis-cli \
    -a "${REDIS_PASSWORD:-}" --no-auth-warning BGSAVE 2>/dev/null || true
  sleep 2
fi

log "预备份检查完成"
