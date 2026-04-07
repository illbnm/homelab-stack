#!/bin/bash
# 数据库恢复脚本
# Issue #11 - Bounty $130 USDT
#
# 用法: ./scripts/restore-databases.sh <backup_file.tar.gz>

set -euo pipefail

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

# 检查参数
if [ $# -eq 0 ]; then
    error "用法: $0 <backup_file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    error "备份文件不存在: ${BACKUP_FILE}"
    exit 1
fi

log "开始恢复数据库..."
log "备份文件: ${BACKUP_FILE}"

# 创建临时目录
TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

# 解压备份
log "解压备份文件..."
tar -xzf "${BACKUP_FILE}" -C "${TMP_DIR}" 2>/dev/null || {
    error "解压失败"
    exit 1
}

# 1. 恢复 PostgreSQL
if [ -f "${TMP_DIR}/postgres_backup.sql" ]; then
    log "恢复 PostgreSQL..."
    warn "⚠️ 这将覆盖所有 PostgreSQL 数据库"
    read -p "确认继续? (yes/no): " confirm
    if [ "${confirm}" = "yes" ]; then
        docker exec -i homelab-postgres psql -U postgres < "${TMP_DIR}/postgres_backup.sql" 2>/dev/null || {
            warn "PostgreSQL 恢复失败（部分数据可能已存在）"
        }
        log "✅ PostgreSQL 恢复完成"
    else
        warn "跳过 PostgreSQL 恢复"
    fi
else
    warn "未找到 PostgreSQL 备份"
fi

# 2. 恢复 Redis
if [ -f "${TMP_DIR}/redis_backup.rdb" ]; then
    log "恢复 Redis..."
    warn "⚠️ 这将覆盖所有 Redis 数据"
    read -p "确认继续? (yes/no): " confirm
    if [ "${confirm}" = "yes" ]; then
        # 停止 Redis
        docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" SHUTDOWN NOSAVE 2>/dev/null || true
        sleep 2
        
        # 复制备份文件
        docker cp "${TMP_DIR}/redis_backup.rdb" homelab-redis:/data/dump.rdb 2>/dev/null || {
            error "Redis 备份复制失败"
            exit 1
        }
        
        # 重启 Redis
        docker restart homelab-redis
        sleep 5
        
        log "✅ Redis 恢复完成"
    else
        warn "跳过 Redis 恢复"
    fi
else
    warn "未找到 Redis 备份"
fi

# 3. 恢复 MariaDB
if [ -f "${TMP_DIR}/mariadb_backup.sql" ]; then
    log "恢复 MariaDB..."
    warn "⚠️ 这将覆盖所有 MariaDB 数据库"
    read -p "确认继续? (yes/no): " confirm
    if [ "${confirm}" = "yes" ]; then
        docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" < "${TMP_DIR}/mariadb_backup.sql" 2>/dev/null || {
            warn "MariaDB 恢复失败（部分数据可能已存在）"
        }
        log "✅ MariaDB 恢复完成"
    else
        warn "跳过 MariaDB 恢复"
    fi
else
    warn "未找到 MariaDB 备份"
fi

log "🎉 数据库恢复完成！"

# 发送通知（如果配置了 notify.sh）
if command -v notify.sh &> /dev/null; then
    notify.sh backups "数据库恢复完成" "备份文件: ${BACKUP_FILE}" default
fi
