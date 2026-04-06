#!/bin/bash
# ============================================
# Backup & DR - 灾难恢复脚本
# Issue #12 - $150 Bounty
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# 配置
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RESTORE_DIR="${RESTORE_DIR:-/restore}"

# ============================================
# 1. 列出可用备份
# ============================================
list_backups() {
    log_info "可用备份列表:"
    echo ""
    echo "=== Restic 快照 ==="
    if command -v restic &> /dev/null; then
        export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BACKUP_DIR/restic}"
        export RESTIC_PASSWORD="${RESTIC_PASSWORD:-ResticBackup123!}"
        restic snapshots --repo "$RESTIC_REPOSITORY" --password-file <(echo "$RESTIC_PASSWORD") 2>/dev/null || echo "无 Restic 快照"
    fi
    
    echo ""
    echo "=== 日常备份 ==="
    ls -lht "$BACKUP_DIR/daily/" 2>/dev/null | head -20 || echo "无日常备份"
    
    echo ""
    echo "=== 紧急备份 ==="
    ls -lht "$BACKUP_DIR/emergency/" 2>/dev/null | head -10 || echo "无紧急备份"
}

# ============================================
# 2. Restic 恢复
# ============================================
restore_with_restic() {
    local SNAPSHOT_ID="${1:-latest}"
    local TARGET_DIR="${2:-$RESTORE_DIR}"
    
    log_info "从 Restic 恢复备份 (快照：$SNAPSHOT_ID)..."
    
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BACKUP_DIR/restic}"
    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-ResticBackup123!}"
    
    mkdir -p "$TARGET_DIR"
    
    if [ "$SNAPSHOT_ID" = "latest" ]; then
        restic restore latest \
            --repo "$RESTIC_REPOSITORY" \
            --password-file <(echo "$RESTIC_PASSWORD") \
            --target "$TARGET_DIR"
    else
        restic restore "$SNAPSHOT_ID" \
            --repo "$RESTIC_REPOSITORY" \
            --password-file <(echo "$RESTIC_PASSWORD") \
            --target "$TARGET_DIR"
    fi
    
    log_success "恢复到：$TARGET_DIR"
}

# ============================================
# 3. 配置文件恢复
# ============================================
restore_configs() {
    local BACKUP_FILE="${1:-}"
    
    log_info "恢复配置文件..."
    
    if [ -z "$BACKUP_FILE" ]; then
        # 使用最新的配置备份
        BACKUP_FILE=$(ls -t "$BACKUP_DIR/daily"/configs_*/configs.tar.gz 2>/dev/null | head -1)
    fi
    
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        tar -xzf "$BACKUP_FILE" -C /
        log_success "配置文件已恢复"
    else
        log_error "未找到配置备份文件"
        return 1
    fi
}

# ============================================
# 4. 数据库恢复
# ============================================
restore_databases() {
    local BACKUP_DIR_PATH="${1:-$BACKUP_DIR/daily}"
    
    log_info "恢复数据库..."
    
    # PostgreSQL 恢复
    local PG_DUMP=$(ls -t "$BACKUP_DIR_PATH"/databases_*/postgres.sql 2>/dev/null | head -1)
    if [ -n "$PG_DUMP" ] && [ -f "$PG_DUMP" ]; then
        log_info "恢复 PostgreSQL..."
        PGPASSWORD="${POSTGRES_PASSWORD:-}" psql -h "${POSTGRES_HOST:-localhost}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-homelab}" < "$PG_DUMP"
        log_success "PostgreSQL 已恢复"
    fi
    
    # MySQL 恢复
    local MYSQL_DUMP=$(ls -t "$BACKUP_DIR_PATH"/databases_*/mysql.sql 2>/dev/null | head -1)
    if [ -n "$MYSQL_DUMP" ] && [ -f "$MYSQL_DUMP" ]; then
        log_info "恢复 MySQL..."
        mysql -h "${MYSQL_HOST:-localhost}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-}" < "$MYSQL_DUMP"
        log_success "MySQL 已恢复"
    fi
    
    log_success "数据库恢复完成"
}

# ============================================
# 5. 完整系统恢复
# ============================================
full_system_restore() {
    local SNAPSHOT_ID="${1:-latest}"
    
    log_warning "⚠️  即将执行完整系统恢复!"
    log_warning "⚠️  此操作将覆盖现有数据!"
    echo ""
    read -p "确认继续？(yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_error "取消恢复"
        exit 1
    fi
    
    log_info "开始完整系统恢复..."
    
    # 1. 停止所有服务
    log_info "停止所有服务..."
    cd /home/ggmini/.openclaw/workspace/homelab-stack
    docker-compose down || true
    
    # 2. 恢复配置文件
    restore_configs
    
    # 3. 恢复数据
    restore_with_restic "$SNAPSHOT_ID" "/home/ggmini/.openclaw/workspace"
    
    # 4. 恢复数据库
    restore_databases
    
    # 5. 重启服务
    log_info "重启所有服务..."
    docker-compose up -d
    
    log_success "=========================================="
    log_success "完整系统恢复完成!"
    log_success "=========================================="
}

# ============================================
# 6. 验证备份完整性
# ============================================
verify_backup() {
    log_info "验证备份完整性..."
    
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$BACKUP_DIR/restic}"
    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-ResticBackup123!}"
    
    if command -v restic &> /dev/null; then
        restic check --repo "$RESTIC_REPOSITORY" --password-file <(echo "$RESTIC_PASSWORD")
        log_success "Restic 仓库完整性验证通过"
    fi
    
    # 检查备份文件大小
    log_info "检查备份文件..."
    du -sh "$BACKUP_DIR"/* 2>/dev/null
    
    log_success "备份验证完成"
}

# ============================================
# 7. 创建紧急备份
# ============================================
create_emergency_backup() {
    log_info "创建紧急备份..."
    
    EMERGENCY_DIR="$BACKUP_DIR/emergency/emergency_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$EMERGENCY_DIR"
    
    # 快速备份关键数据
    tar -czf "$EMERGENCY_DIR/workspace.tar.gz" \
        -C /home/ggmini/.openclaw workspace/ 2>/dev/null || true
    
    tar -czf "$EMERGENCY_DIR/configs.tar.gz" \
        -C /home/ggmini/.openclaw/workspace/homelab-stack config/ 2>/dev/null || true
    
    cp /home/ggmini/.openclaw/workspace/homelab-stack/.env "$EMERGENCY_DIR/" 2>/dev/null || true
    
    log_success "紧急备份已创建：$EMERGENCY_DIR"
}

# ============================================
# 使用帮助
# ============================================
show_help() {
    cat << EOF
灾难恢复工具 - Backup & DR Stack

用法：$0 <命令> [参数]

命令:
  list                    列出所有可用备份
  restore-restic [ID]     从 Restic 恢复 (默认：latest)
  restore-configs [文件]   恢复配置文件
  restore-databases [目录] 恢复数据库
  full-restore [ID]       完整系统恢复
  verify                  验证备份完整性
  emergency               创建紧急备份
  help                    显示此帮助

示例:
  $0 list                          # 列出备份
  $0 restore-restic latest         # 恢复最新快照
  $0 full-restore 2026-03-22       # 完整恢复到指定日期
  $0 emergency                     # 创建紧急备份

EOF
}

# ============================================
# 主流程
# ============================================
case "${1:-help}" in
    list)
        list_backups
        ;;
    restore-restic)
        restore_with_restic "${2:-latest}" "${3:-$RESTORE_DIR}"
        ;;
    restore-configs)
        restore_configs "$2"
        ;;
    restore-databases)
        restore_databases "$2"
        ;;
    full-restore)
        full_system_restore "$2"
        ;;
    verify)
        verify_backup
        ;;
    emergency)
        create_emergency_backup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "未知命令：$1"
        show_help
        exit 1
        ;;
esac
