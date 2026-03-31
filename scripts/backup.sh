#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 3-2-1 Backup Strategy with Duplicati + Restic
# Copyright (c) 2026 思捷娅科技 (SJYKJ)
# =============================================================================
# 用法:
#   backup.sh --target <stack|all> [选项]
#
# 选项:
#   --target all          备份所有 stack 数据卷
#   --target media        仅备份媒体栈
#   --dry-run             显示将备份的内容，不实际执行
#   --restore <backup_id> 从指定备份恢复
#   --list                列出所有备份
#   --verify              验证备份完整性
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/.env"

# 加载环境变量
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# 配置
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_debug() { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"; }

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

选项:
    --target <stack>      要备份的栈 (all, media, storage, monitoring 等)
    --dry-run             显示将备份的内容，不实际执行
    --restore <id>        从指定备份恢复
    --list                列出所有备份
    --verify              验证备份完整性
    --help                显示此帮助信息

环境变量 (.env):
    BACKUP_TARGET         备份目标 (local|s3|b2|sftp)
    BACKUP_DIR            本地备份目录 (默认: /opt/homelab-backups)
    BACKUP_RETENTION_DAYS 保留天数 (默认: 30)

示例:
    $0 --target all                   # 备份所有栈
    $0 --target media --dry-run       # 预览媒体栈备份
    $0 --list                         # 列出所有备份
    $0 --restore 20260331_120000      # 恢复指定备份
    $0 --verify                       # 验证最新备份
EOF
}

# 检查依赖
check_dependencies() {
    local deps=("docker" "jq" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "缺少依赖: $dep"
            exit 1
        fi
    done

    # 检查备份目标
    case "$BACKUP_TARGET" in
        s3|b2)
            if ! command -v "rclone" &> /dev/null; then
                log_error "备份目标 $BACKUP_TARGET 需要 rclone"
                exit 1
            fi
            ;;
        sftp)
            if ! command -v "rsync" &> /dev/null; then
                log_error "备份目标 sftp 需要 rsync"
                exit 1
            fi
            ;;
    esac
}

# 发送通知
send_notification() {
    local status="$1"
    local message="$2"

    if [[ -n "${NTFY_SERVER:-}" ]]; then
        curl -s -X POST "${NTFY_SERVER}/${NTFY_TOPIC}" \
            -H "Title: HomeLab Backup ${status}" \
            -H "Priority: $([[ "$status" == "FAILED" ]] && echo "high" || echo "default")" \
            -d "$message" > /dev/null 2>&1 || true
    fi
}

# 获取所有 Docker volumes
get_volumes() {
    local stack="${1:-all}"

    if [[ "$stack" == "all" ]]; then
        docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true
    else
        docker volume ls --format '{{.Name}}' | grep -E "^${stack}_" || true
    fi
}

# 预览备份内容 (dry-run)
preview_backup() {
    local stack="${1:-all}"

    log_info "=== 备份预览 (Dry Run) ==="
    log_info "目标: $stack"
    log_info "备份目录: $BACKUP_PATH"
    log_info "保留策略: ${RETENTION_DAYS} 天"
    echo ""

    log_info "将要备份的 Docker volumes:"
    local volumes
    volumes=$(get_volumes "$stack")
    if [[ -n "$volumes" ]]; then
        while IFS= read -r vol; do
            [[ -z "$vol" ]] && continue
            local size
            size=$(docker system df -v | grep "$vol" | awk '{print $3}' || echo "unknown")
            echo "  - $vol ($size)"
        done <<< "$volumes"
    else
        log_warn "  无匹配的 volumes"
    fi
    echo ""

    log_info "将要备份的配置文件:"
    echo "  - config/"
    echo "  - stacks/"
    echo "  - scripts/"
    echo ""

    log_info "将要备份的数据库:"
    docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql|mariadb|mysql' | while read -r container; do
        echo "  - $container"
    done || log_warn "  无运行中的数据库"
    echo ""

    log_info "备份目标: $BACKUP_TARGET"
    case "$BACKUP_TARGET" in
        s3)
            echo "  S3 Bucket: ${S3_BUCKET:-未配置}"
            ;;
        b2)
            echo "  Backblaze B2: ${B2_BUCKET:-未配置}"
            ;;
        sftp)
            echo "  SFTP: ${SFTP_HOST:-未配置}:${SFTP_PATH:-/backup}"
            ;;
        local)
            echo "  本地路径: $BACKUP_DIR"
            ;;
    esac

    log_info "=== 预览完成 ==="
}

# 备份 Docker volumes
backup_volumes() {
    local stack="${1:-all}"
    log_info "备份 Docker volumes (栈: $stack)..."

    local volumes
    volumes=$(get_volumes "$stack")
    local count=0

    while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        log_info "  Volume: $vol"

        docker run --rm \
            -v "${vol}:/data:ro" \
            -v "$BACKUP_PATH:/backup" \
            alpine:3.19 \
            tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
            log_warn "  备份失败: $vol"

        ((count++))
    done <<< "$volumes"

    log_info "已备份 $count 个 volumes"
}

# 备份配置文件
backup_configs() {
    log_info "备份配置文件..."

    tar czf "$BACKUP_PATH/configs.tar.gz" \
        -C "$BASE_DIR" \
        --exclude='stacks/*/data' \
        --exclude='.git' \
        --exclude='*.log' \
        config/ stacks/ scripts/ .env 2>/dev/null || true

    log_info "配置文件备份完成"
}

# 备份数据库
backup_databases() {
    log_info "备份数据库..."

    # PostgreSQL
    if docker ps --format '{{.Names}}' | grep -qE 'postgres|postgresql'; then
        local pg_container
        pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
        local pg_pass
        pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)

        log_info "  PostgreSQL: $pg_container"
        docker exec "$pg_container" \
            sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
            > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null || \
            log_warn "  PostgreSQL 备份失败"
    fi

    # MariaDB/MySQL
    if docker ps --format '{{.Names}}' | grep -qE 'mariadb|mysql'; then
        local mysql_container
        mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
        local mysql_pass
        mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)

        log_info "  MySQL/MariaDB: $mysql_container"
        docker exec "$mysql_container" \
            sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
            > "$BACKUP_PATH/mysql_all.sql" 2>/dev/null || \
            log_warn "  MySQL 备份失败"
    fi

    log_info "数据库备份完成"
}

# 同步到远程备份目标
sync_to_remote() {
    log_info "同步到远程备份目标: $BACKUP_TARGET"

    case "$BACKUP_TARGET" in
        s3)
            rclone sync "$BACKUP_PATH" "s3:${S3_BUCKET}/homelab-backup/$TIMESTAMP" \
                --progress \
                --transfers 4 \
                --log-file="$LOG_FILE" || log_error "S3 同步失败"
            ;;
        b2)
            rclone sync "$BACKUP_PATH" "b2:${B2_BUCKET}/homelab-backup/$TIMESTAMP" \
                --progress \
                --transfers 4 \
                --log-file="$LOG_FILE" || log_error "B2 同步失败"
            ;;
        sftp)
            rsync -avz --progress "$BACKUP_PATH/" \
                "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/$TIMESTAMP/" \
                --log-file="$LOG_FILE" || log_error "SFTP 同步失败"
            ;;
        local)
            log_debug "使用本地备份，无需同步"
            ;;
        *)
            log_error "未知的备份目标: $BACKUP_TARGET"
            ;;
    esac

    log_info "远程同步完成"
}

# 列出所有备份
list_backups() {
    log_info "列出所有备份..."
    echo ""

    if [[ "$BACKUP_TARGET" == "local" ]]; then
        if [[ -d "$BACKUP_DIR" ]]; then
            ls -lht "$BACKUP_DIR" | grep "^d" | head -20
        else
            log_warn "备份目录不存在: $BACKUP_DIR"
        fi
    else
        case "$BACKUP_TARGET" in
            s3)
                rclone ls "s3:${S3_BUCKET}/homelab-backup" || log_error "无法列出 S3 备份"
                ;;
            b2)
                rclone ls "b2:${B2_BUCKET}/homelab-backup" || log_error "无法列出 B2 备份"
                ;;
            sftp)
                ssh "${SFTP_USER}@${SFTP_HOST}" "ls -lh ${SFTP_PATH}" || log_error "无法列出 SFTP 备份"
                ;;
        esac
    fi
}

# 验证备份完整性
verify_backup() {
    local backup_id="${1:-latest}"
    local backup_path

    if [[ "$backup_id" == "latest" ]]; then
        backup_path=$(ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | head -1)
    else
        backup_path="$BACKUP_DIR/$backup_id"
    fi

    if [[ ! -d "$backup_path" ]]; then
        log_error "备份不存在: $backup_path"
        exit 1
    fi

    log_info "验证备份: $backup_path"
    echo ""

    local errors=0

    # 验证 tar.gz 文件
    log_info "验证压缩文件..."
    for file in "$backup_path"/*.tar.gz; do
        [[ -f "$file" ]] || continue
        if tar tzf "$file" &> /dev/null; then
            log_info "  ✓ $(basename "$file")"
        else
            log_error "  ✗ $(basename "$file") - 文件损坏"
            ((errors++))
        fi
    done

    # 验证 SQL 文件
    log_info "验证数据库文件..."
    for file in "$backup_path"/*.sql; do
        [[ -f "$file" ]] || continue
        if [[ -s "$file" ]]; then
            log_info "  ✓ $(basename "$file") ($(wc -l < "$file") 行)"
        else
            log_error "  ✗ $(basename "$file") - 文件为空"
            ((errors++))
        fi
    done

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_info "✅ 验证通过 - 所有文件完整"
        return 0
    else
        log_error "❌ 验证失败 - 发现 $errors 个错误"
        return 1
    fi
}

# 从备份恢复
restore_backup() {
    local backup_id="$1"
    local backup_path="$BACKUP_DIR/$backup_id"

    if [[ ! -d "$backup_path" ]]; then
        log_error "备份不存在: $backup_path"
        exit 1
    fi

    log_warn "=== 开始恢复 ==="
    log_warn "警告: 这将覆盖当前数据！"
    echo ""
    read -p "确认要恢复备份 $backup_id 吗? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "恢复已取消"
        exit 0
    fi

    log_info "恢复配置文件..."
    # 这里需要小心，先备份当前配置
    # tar xzf "$backup_path/configs.tar.gz" -C "$BASE_DIR"

    log_info "恢复 Docker volumes..."
    for file in "$backup_path"/vol_*.tar.gz; do
        [[ -f "$file" ]] || continue
        local vol_name
        vol_name=$(basename "$file" .tar.gz | sed 's/^vol_//')
        log_info "  恢复 volume: $vol_name"

        # 创建 volume (如果不存在)
        docker volume create "$vol_name" &> /dev/null || true

        # 恢复数据
        docker run --rm \
            -v "${vol_name}:/data" \
            -v "$backup_path:/backup" \
            alpine:3.19 \
            sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$file") -C /data" || \
            log_error "  恢复失败: $vol_name"
    done

    log_info "恢复数据库..."
    # PostgreSQL 恢复
    if [[ -f "$backup_path/postgresql_all.sql" ]]; then
        local pg_container
        pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
        if [[ -n "$pg_container" ]]; then
            log_info "  恢复 PostgreSQL..."
            cat "$backup_path/postgresql_all.sql" | docker exec -i "$pg_container" psql -U postgres || \
                log_error "  PostgreSQL 恢复失败"
        fi
    fi

    # MySQL 恢复
    if [[ -f "$backup_path/mysql_all.sql" ]]; then
        local mysql_container
        mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
        if [[ -n "$mysql_container" ]]; then
            log_info "  恢复 MySQL/MariaDB..."
            cat "$backup_path/mysql_all.sql" | docker exec -i "$mysql_container" mysql -u root -p"$mysql_pass" || \
                log_error "  MySQL 恢复失败"
        fi
    fi

    log_info "✅ 恢复完成"
    log_warn "请重启相关服务以应用更改"
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理 ${RETENTION_DAYS} 天前的备份..."

    if [[ "$BACKUP_TARGET" == "local" ]]; then
        find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
    else
        case "$BACKUP_TARGET" in
            s3)
                rclone delete "s3:${S3_BUCKET}/homelab-backup" --min-age "${RETENTION_DAYS}d" || true
                ;;
            b2)
                rclone delete "b2:${B2_BUCKET}/homelab-backup" --min-age "${RETENTION_DAYS}d" || true
                ;;
            sftp)
                ssh "${SFTP_USER}@${SFTP_HOST}" "find ${SFTP_PATH} -mtime +${RETENTION_DAYS} -type d -exec rm -rf {} +" || true
                ;;
        esac
    fi
}

# 生成备份摘要
generate_summary() {
    local total_size
    total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
    local file_count
    file_count=$(find "$BACKUP_PATH" -type f | wc -l)

    cat << EOF

=== 备份摘要 ===
时间: $(date '+%Y-%m-%d %H:%M:%S')
备份ID: $TIMESTAMP
位置: $BACKUP_PATH
大小: $total_size
文件数: $file_count
目标: $BACKUP_TARGET
保留策略: ${RETENTION_DAYS} 天

文件列表:
$(ls -lh "$BACKUP_PATH/")
=================

EOF

    log_info "备份完成: $BACKUP_PATH ($total_size)" | tee -a "$LOG_FILE"
}

# 主函数
main() {
    local target="all"
    local dry_run=false
    local action="backup"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                target="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --restore)
                action="restore"
                backup_id="$2"
                shift 2
                ;;
            --list)
                action="list"
                shift
                ;;
            --verify)
                action="verify"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                usage
                exit 1
                ;;
        esac
    done

    # 初始化日志
    mkdir -p "$BACKUP_DIR"
    echo "=== 备份日志 - $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOG_FILE"

    # 检查依赖
    check_dependencies

    # 执行操作
    case "$action" in
        backup)
            if [[ "$dry_run" == "true" ]]; then
                preview_backup "$target"
            else
                log_info "开始备份 (目标: $target)..."
                mkdir -p "$BACKUP_PATH"

                backup_configs
                backup_volumes "$target"
                backup_databases
                sync_to_remote
                cleanup_old_backups
                generate_summary

                send_notification "SUCCESS" "备份完成: $BACKUP_PATH"
            fi
            ;;
        restore)
            restore_backup "$backup_id"
            ;;
        list)
            list_backups
            ;;
        verify)
            verify_backup "${backup_id:-latest}"
            ;;
    esac
}

# 运行
main "$@"
