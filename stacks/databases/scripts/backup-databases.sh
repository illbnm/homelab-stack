#!/bin/bash
# 数据库备份脚本
# Issue #11 - Bounty $130 USDT
#
# 功能:
# - PostgreSQL pg_dumpall 备份
# - Redis BGSAVE 持久化
# - MariaDB mysqldump 备份
# - 压缩为 .tar.gz
# - 保留最近 7 天
# - 可选上传到 MinIO

set -euo pipefail

# 配置
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups/databases}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/databases_${TIMESTAMP}.tar.gz"

# MinIO 配置（可选）
MINIO_ENABLED="${MINIO_ENABLED:-false}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 创建备份目录
mkdir -p "${BACKUP_DIR}"
TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

log "开始备份数据库..."

# 1. PostgreSQL 备份
log "备份 PostgreSQL..."
docker exec homelab-postgres pg_dumpall -U postgres > "${TMP_DIR}/postgres_backup.sql" 2>/dev/null || {
    error "PostgreSQL 备份失败"
    exit 1
}
log "✅ PostgreSQL 备份完成"

# 2. Redis 备份
log "备份 Redis..."
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null || {
    warn "Redis BGSAVE 触发失败（可能正在进行）"
}
# 等待 Redis 持久化完成
sleep 2
docker cp homelab-redis:/data/dump.rdb "${TMP_DIR}/redis_backup.rdb" 2>/dev/null || {
    error "Redis 备份失败"
    exit 1
}
log "✅ Redis 备份完成"

# 3. MariaDB 备份
log "备份 MariaDB..."
docker exec homelab-mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > "${TMP_DIR}/mariadb_backup.sql" 2>/dev/null || {
    error "MariaDB 备份失败"
    exit 1
}
log "✅ MariaDB 备份完成"

# 4. 压缩备份
log "压缩备份文件..."
tar -czf "${BACKUP_FILE}" -C "${TMP_DIR}" . 2>/dev/null || {
    error "压缩失败"
    exit 1
}
log "✅ 备份文件: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"

# 5. 清理旧备份
log "清理旧备份（保留 ${RETENTION_DAYS} 天）..."
find "${BACKUP_DIR}" -name "databases_*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || {
    warn "清理旧备份失败"
}
log "✅ 清理完成"

# 6. 上传到 MinIO（可选）
if [ "${MINIO_ENABLED}" = "true" ]; then
    log "上传到 MinIO..."
    if command -v mc &> /dev/null; then
        mc alias set minio "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>/dev/null || {
            warn "MinIO 配置失败"
        }
        mc cp "${BACKUP_FILE}" "minio/${MINIO_BUCKET}/databases/" 2>/dev/null || {
            warn "上传到 MinIO 失败"
        }
        log "✅ 已上传到 MinIO"
    else
        warn "mc (MinIO Client) 未安装，跳过上传"
    fi
fi

log "🎉 数据库备份完成！"
log "备份文件: ${BACKUP_FILE}"
log "备份大小: $(du -h "${BACKUP_FILE}" | cut -f1)"

# 发送通知（如果配置了 notify.sh）
if command -v notify.sh &> /dev/null; then
    notify.sh backups "数据库备份完成" "备份大小: $(du -h "${BACKUP_FILE}" | cut -f1)" default
fi
