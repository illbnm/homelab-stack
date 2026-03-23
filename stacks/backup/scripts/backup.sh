#!/bin/bash
#
# Homelab 备份脚本 - 支持 3-2-1 备份策略
# 用法：backup.sh --target <stack|all> [选项]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
NOTIFICATION_TOPIC="${NOTIFICATION_TOPIC:-backup}"
NOTIFICATION_SERVER="${NOTIFICATION_SERVER:-ntfy:8080}"
RESTIC_SERVER="${RESTIC_SERVER:-http://restic-server:8000}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"

# Homelab Stack 数据目录
STACKS_DIR="${STACKS_DIR:-/data}"

# 日志文件
LOG_FILE="${BACKUP_ROOT}/backup.log"

# 打印函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 发送通知
send_notification() {
    local priority="$1"
    local title="$2"
    local message="$3"
    
    if command -v curl &> /dev/null; then
        curl -s -X POST "http://${NOTIFICATION_SERVER}/${NOTIFICATION_TOPIC}" \
            -H "Title: ${title}" \
            -H "Priority: ${priority}" \
            -d "${message}" || true
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Homelab 备份脚本 - 3-2-1 备份策略

用法:
  $0 [选项]

选项:
  --target <all|media|base|db|sso|ai|notifications>
                        指定备份目标 (默认：all)
  --dry-run             显示将备份的内容，不实际执行
  --restore <backup_id> 从指定备份恢复
  --list                列出所有备份
  --verify              验证备份完整性
  --help                显示此帮助信息

备份目标说明:
  all           - 备份所有 stack 数据卷
  media         - 仅备份媒体栈 (Jellyfin/Immich 等)
  base          - 仅备份基础栈 (网络/存储)
  db            - 仅备份数据库栈 (PostgreSQL/MySQL)
  sso           - 仅备份 SSO 栈 (Authentik)
  ai            - 仅备份 AI 栈 (Ollama/Open WebUI)
  notifications - 仅备份通知栈 (ntfy/Gotify)

备份目标类型 (通过 BACKUP_TARGET 环境变量设置):
  local  - 本地目录备份
  s3     - AWS S3 或兼容存储
  b2     - Backblaze B2
  sftp   - SFTP 服务器
  r2     - Cloudflare R2

示例:
  $0 --target all                    # 备份所有内容
  $0 --target media --dry-run        # 预览媒体栈备份
  $0 --list                          # 列出所有备份
  $0 --verify                        # 验证备份完整性
  $0 --restore 2026-03-24_020000     # 从指定备份恢复

EOF
}

# 获取 Stack 数据目录
get_stack_dirs() {
    local target="$1"
    case "$target" in
        all)
            echo "base db sso media ai notifications robustness backup"
            ;;
        media)
            echo "media"
            ;;
        base)
            echo "base"
            ;;
        db)
            echo "db"
            ;;
        sso)
            echo "sso"
            ;;
        ai)
            echo "ai"
            ;;
        notifications)
            echo "notifications"
            ;;
        *)
            echo "$target"
            ;;
    esac
}

# 执行 Restic 备份
restic_backup() {
    local source_dir="$1"
    local backup_name="$2"
    local timestamp="$3"
    
    if [ -z "$RESTIC_PASSWORD" ]; then
        log_warn "RESTIC_PASSWORD 未设置，跳过 Restic 备份"
        return 1
    fi
    
    local repo_path="${BACKUP_ROOT}/restic/${backup_name}"
    
    log_info "初始化 Restic 仓库：${repo_path}"
    restic init --repo "${repo_path}" --password-file <(echo "$RESTIC_PASSWORD") 2>/dev/null || true
    
    log_info "执行备份：${source_dir} -> ${repo_path}"
    restic backup \
        --repo "${repo_path}" \
        --password-file <(echo "$RESTIC_PASSWORD") \
        --tag "stack=${backup_name}" \
        --tag "date=${timestamp}" \
        "${source_dir}"
    
    # 清理旧备份
    log_info "清理 ${BACKUP_RETENTION_DAYS} 天前的备份"
    restic forget \
        --repo "${repo_path}" \
        --password-file <(echo "$RESTIC_PASSWORD") \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --prune
}

# 执行 Duplicati 备份
duplicati_backup() {
    local source_dir="$1"
    local backup_name="$2"
    
    log_info "Duplicati 备份通过 Web UI 配置，请访问 http://backup.\${DOMAIN}:8200"
    log_info "备份源：${source_dir}"
}

# 执行本地备份
local_backup() {
    local source_dir="$1"
    local backup_name="$2"
    local timestamp="$3"
    
    local dest_dir="${BACKUP_ROOT}/${backup_name}/${timestamp}"
    
    log_info "创建备份目录：${dest_dir}"
    mkdir -p "$dest_dir"
    
    if [ -d "$source_dir" ]; then
        log_info "备份数据：${source_dir} -> ${dest_dir}"
        rsync -av --delete "${source_dir}/" "${dest_dir}/"
        
        # 创建校验和
        log_info "生成校验和文件"
        (cd "$dest_dir" && find . -type f -exec md5sum {} \; > checksums.md5)
        
        log_success "本地备份完成：${dest_dir}"
    else
        log_warn "源目录不存在：${source_dir}"
    fi
}

# 列出所有备份
list_backups() {
    log_info "可用的备份:"
    echo ""
    
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -maxdepth 3 -name "checksums.md5" -type f 2>/dev/null | while read checksum_file; do
            backup_dir=$(dirname "$checksum_file")
            backup_date=$(basename "$(dirname "$backup_dir")")
            backup_stack=$(basename "$backup_dir")
            backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
            echo "  📦 ${backup_stack}/${backup_date} (${backup_size})"
        done
    else
        echo "  暂无备份"
    fi
    echo ""
}

# 验证备份完整性
verify_backups() {
    log_info "验证备份完整性..."
    local errors=0
    
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -name "checksums.md5" -type f 2>/dev/null | while read checksum_file; do
            backup_dir=$(dirname "$checksum_file")
            log_info "验证：${backup_dir}"
            
            if (cd "$backup_dir" && md5sum -c checksums.md5 --quiet 2>/dev/null); then
                log_success "✓ $(basename "$backup_dir") 校验通过"
            else
                log_error "✗ $(basename "$backup_dir") 校验失败"
                ((errors++)) || true
            fi
        done
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "所有备份验证通过!"
    else
        log_error "${errors} 个备份验证失败"
        return 1
    fi
}

# 恢复备份
restore_backup() {
    local backup_id="$1"
    local restore_target="${2:-/data/restored}"
    
    log_info "从备份恢复：${backup_id}"
    log_info "恢复目标：${restore_target}"
    
    local backup_path="${BACKUP_ROOT}/*/${backup_id}"
    
    if [ -d "$backup_path" ]; then
        mkdir -p "$restore_target"
        rsync -av "${backup_path}/" "${restore_target}/"
        log_success "恢复完成：${restore_target}"
    else
        log_error "备份不存在：${backup_id}"
        return 1
    fi
}

# 主备份函数
do_backup() {
    local target="$1"
    local dry_run="$2"
    
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local stacks=$(get_stack_dirs "$target")
    
    log_info "=========================================="
    log_info "Homelab 备份开始"
    log_info "时间：${timestamp}"
    log_info "目标：${target}"
    log_info "备份类型：${BACKUP_TARGET}"
    log_info "=========================================="
    
    send_notification "3" "🔄 备份开始" "开始备份 ${target} (${timestamp})"
    
    for stack in $stacks; do
        local source_dir="${STACKS_DIR}/${stack}"
        log_info ""
        log_info "处理 Stack: ${stack}"
        
        if [ "$dry_run" = "true" ]; then
            log_info "[DRY-RUN] 将备份：${source_dir}"
            if [ -d "$source_dir" ]; then
                local size=$(du -sh "$source_dir" 2>/dev/null | cut -f1)
                local files=$(find "$source_dir" -type f 2>/dev/null | wc -l)
                log_info "  大小：${size}, 文件数：${files}"
            else
                log_warn "  目录不存在"
            fi
            continue
        fi
        
        case "$BACKUP_TARGET" in
            local)
                local_backup "$source_dir" "$stack" "$timestamp"
                ;;
            restic)
                restic_backup "$source_dir" "$stack" "$timestamp"
                ;;
            duplicati)
                duplicati_backup "$source_dir" "$stack"
                ;;
            *)
                log_warn "未知的备份类型：${BACKUP_TARGET}，使用本地备份"
                local_backup "$source_dir" "$stack" "$timestamp"
                ;;
        esac
    done
    
    log_info ""
    log_info "=========================================="
    log_success "备份完成!"
    log_info "=========================================="
    
    send_notification "3" "✅ 备份完成" "备份 ${target} 完成 (${timestamp})"
}

# 解析参数
TARGET="all"
DRY_RUN="false"
ACTION="backup"
RESTORE_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --list)
            ACTION="list"
            shift
            ;;
        --verify)
            ACTION="verify"
            shift
            ;;
        --restore)
            ACTION="restore"
            RESTORE_ID="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项：$1"
            show_help
            exit 1
            ;;
    esac
done

# 执行操作
case "$ACTION" in
    backup)
        do_backup "$TARGET" "$DRY_RUN"
        ;;
    list)
        list_backups
        ;;
    verify)
        verify_backups
        ;;
    restore)
        if [ -z "$RESTORE_ID" ]; then
            log_error "请指定要恢复的备份 ID"
            show_help
            exit 1
        fi
        restore_backup "$RESTORE_ID"
        ;;
esac
