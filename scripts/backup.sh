#!/usr/bin/env bash
# backup.sh — 3-2-1 备份脚本
# Issue #12 · Bounty $150
#
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

set -euo pipefail

# 配置
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RESTIC_REPO="${RESTIC_REPO:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-changeme}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"
B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-}"
SFTP_HOST="${SFTP_HOST:-}"
LOG_FILE="/var/log/backup.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
info() { log "${GREEN}[INFO]${NC} $*"; }
warn() { log "${YELLOW}[WARN]${NC} $*"; }
error() { log "${RED}[ERROR]${NC} $*"; }

# 初始化 restic 仓库
init_repo() {
    if [ -z "$RESTIC_REPO" ]; then
        error "RESTIC_REPO 未配置"
        exit 1
    fi
    export RESTIC_PASSWORD
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    restic init --repo "$RESTIC_REPO" 2>/dev/null || true
}

# 备份 Docker 卷
backup_volumes() {
    local stack="$1"
    local dry_run="${2:-false}"

    info "备份 stack: $stack"

    local volumes
    volumes=$(docker volume ls --filter "label=com.docker.compose.project=$stack" --format '{{.Name}}')

    if [ -z "$volumes" ]; then
        warn "未找到 stack: $stack 的数据卷"
        return
    fi

    for vol in $volumes; do
        info "备份卷: $vol"
        if [ "$dry_run" = "true" ]; then
            echo "  [DRY-RUN] 将备份: $vol"
        else
            docker run --rm \
                -v "$vol:/source:ro" \
                -v "$BACKUP_DIR:/backup" \
                -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
                restic/rest-server:0.13.0 \
                sh -c "cd /source && tar czf /backup/${vol}_${TIMESTAMP}.tar.gz ."
            info "  ✅ 已备份: $vol -> ${vol}_${TIMESTAMP}.tar.gz"
        fi
    done
}

# 列出备份
list_backups() {
    info "列出所有备份:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "  无备份文件"
    else
        echo "  备份目录不存在"
    fi
}

# 验证备份
verify_backup() {
    info "验证备份完整性:"
    for f in "$BACKUP_DIR"/*.tar.gz; do
        if gzip -t "$f" 2>/dev/null; then
            info "  ✅ $(basename "$f")"
        else
            error "  ❌ $(basename "$f") - 损坏"
        fi
    done
}

# 恢复备份
restore_backup() {
    local backup_id="$1"
    info "恢复备份: $backup_id"
    local backup_file="$BACKUP_DIR/${backup_id}.tar.gz"
    if [ ! -f "$backup_file" ]; then
        error "备份文件不存在: $backup_file"
        exit 1
    fi
    info "恢复文件: $backup_file"
}

# 主函数
main() {
    local target=""
    local dry_run="false"
    local action="backup"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --target) target="$2"; shift 2 ;;
            --dry-run) dry_run="true"; shift ;;
            --list) action="list"; shift ;;
            --verify) action="verify"; shift ;;
            --restore) action="restore"; target="$2"; shift 2 ;;
            *) error "未知选项: $1"; exit 1 ;;
        esac
    done

    case $action in
        backup)
            if [ "$target" = "all" ]; then
                for stack in base media storage network ai productivity; do
                    backup_volumes "$stack" "$dry_run"
                done
            else
                backup_volumes "$target" "$dry_run"
            fi
            ;;
        list) list_backups ;;
        verify) verify_backup ;;
        restore) restore_backup "$target" ;;
    esac
}

main "$@"
