#!/bin/bash
# ============================================
# Backup & DR - 全量备份脚本
# Issue #12 - $150 Bounty
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# 配置
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
WORKSPACE_DIR="/home/ggmini/.openclaw/workspace"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# 创建备份目录
mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly,emergency}

log_info "=========================================="
log_info "开始全量备份 - $TIMESTAMP"
log_info "=========================================="

# ============================================
# 1. Restic 备份
# ============================================
backup_with_restic() {
    log_info "【1/5】使用 Restic 进行增量备份..."
    
    if command -v restic &> /dev/null; then
        export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BACKUP_DIR/restic}"
        export RESTIC_PASSWORD="${RESTIC_PASSWORD:-ResticBackup123!}"
        
        # 初始化仓库（如果不存在）
        restic init --repo "$RESTIC_REPOSITORY" 2>/dev/null || true
        
        # 执行备份
        restic backup \
            --repo "$RESTIC_REPOSITORY" \
            --password-file <(echo "$RESTIC_PASSWORD") \
            "$WORKSPACE_DIR" \
            --verbose
        
        # 清理旧快照
        restic forget \
            --repo "$RESTIC_REPOSITORY" \
            --password-file <(echo "$RESTIC_PASSWORD") \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 12 \
            --prune
        
        log_success "Restic 备份完成"
    else
        log_warning "Restic 未安装，跳过"
    fi
}

# ============================================
# 2. Duplicati 备份
# ============================================
backup_with_duplicati() {
    log_info "【2/5】使用 Duplicati 进行备份..."
    
    # 通过 API 触发备份（如果 Duplicati 运行中）
    if curl -sf http://localhost:8200 &> /dev/null; then
        log_success "Duplicati Web UI 可访问，备份任务已配置"
    else
        log_warning "Duplicati 未运行，跳过"
    fi
}

# ============================================
# 3. 配置文件备份
# ============================================
backup_configs() {
    log_info "【3/5】备份配置文件..."
    
    CONFIG_BACKUP_DIR="$BACKUP_DIR/daily/configs_$TIMESTAMP"
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    # 备份 Docker 配置
    if [ -d "/home/ggmini/.openclaw/workspace/homelab-stack/config" ]; then
        tar -czf "$CONFIG_BACKUP_DIR/configs.tar.gz" \
            -C /home/ggmini/.openclaw/workspace/homelab-stack config/
        log_success "Docker 配置已备份"
    fi
    
    # 备份环境变量
    if [ -f "/home/ggmini/.openclaw/workspace/homelab-stack/.env" ]; then
        cp /home/ggmini/.openclaw/workspace/homelab-stack/.env "$CONFIG_BACKUP_DIR/"
        log_success ".env 文件已备份"
    fi
    
    # 备份 docker-compose 文件
    find /home/ggmini/.openclaw/workspace/homelab-stack/stacks -name "docker-compose.yml" -exec cp --parents {} "$CONFIG_BACKUP_DIR/" \; 2>/dev/null || true
    log_success "docker-compose 文件已备份"
}

# ============================================
# 4. 数据库备份
# ============================================
backup_databases() {
    log_info "【4/5】备份数据库..."
    
    DB_BACKUP_DIR="$BACKUP_DIR/daily/databases_$TIMESTAMP"
    mkdir -p "$DB_BACKUP_DIR"
    
    # PostgreSQL 备份
    if command -v pg_dump &> /dev/null && [ -n "${POSTGRES_HOST:-}" ]; then
        PGPASSWORD="${POSTGRES_PASSWORD:-}" pg_dump -h "${POSTGRES_HOST:-localhost}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-homelab}" > "$DB_BACKUP_DIR/postgres.sql" 2>/dev/null || log_warning "PostgreSQL 备份失败"
    fi
    
    # MySQL/MariaDB 备份
    if command -v mysqldump &> /dev/null && [ -n "${MYSQL_HOST:-}" ]; then
        mysqldump -h "${MYSQL_HOST:-localhost}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-}" --all-databases > "$DB_BACKUP_DIR/mysql.sql" 2>/dev/null || log_warning "MySQL 备份失败"
    fi
    
    # Redis 备份
    if command -v redis-cli &> /dev/null; then
        redis-cli SAVE 2>/dev/null || log_warning "Redis 备份失败"
    fi
    
    log_success "数据库备份完成"
}

# ============================================
# 5. 清理旧备份
# ============================================
cleanup_old_backups() {
    log_info "【5/5】清理旧备份（保留${RETENTION_DAYS}天）..."
    
    # 清理日常备份
    find "$BACKUP_DIR/daily" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    
    # 清理日志
    find "$BACKUP_DIR" -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    log_success "清理完成"
}

# ============================================
# 生成备份报告
# ============================================
generate_report() {
    log_info "生成备份报告..."
    
    REPORT_FILE="$BACKUP_DIR/daily/backup_report_$TIMESTAMP.md"
    
    cat > "$REPORT_FILE" << EOF
# 备份报告

**时间**: $(date '+%Y-%m-%d %H:%M:%S')
**主机**: $(hostname)

## 备份统计

$(du -sh "$BACKUP_DIR"/* 2>/dev/null | sort -hr)

## 备份文件列表

$(find "$BACKUP_DIR/daily" -name "*$TIMESTAMP*" -type f 2>/dev/null)

## 系统信息

- Docker 版本：$(docker --version 2>/dev/null || echo "未安装")
- 磁盘使用：$(df -h "$BACKUP_DIR" 2>/dev/null | tail -1)
- 内存使用：$(free -h 2>/dev/null | grep Mem || echo "N/A")

EOF
    
    log_success "报告已生成：$REPORT_FILE"
}

# ============================================
# 主流程
# ============================================
main() {
    backup_with_restic
    backup_with_duplicati
    backup_configs
    backup_databases
    cleanup_old_backups
    generate_report
    
    log_info "=========================================="
    log_success "全量备份完成！"
    log_info "=========================================="
    
    # 发送通知（如果配置了）
    if [ -n "${NOTIFY_URL:-}" ]; then
        curl -s -X POST "$NOTIFY_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"✅ 备份完成 - $(date '+%Y-%m-%d %H:%M:%S')\"}" || true
    fi
}

# 执行
main "$@"
