#!/bin/bash
# ================================================
# 3-2-1 Backup Script
# 使用 Restic 实现增量备份
# ================================================

set -e

# 加载环境变量
if [ -f .env ]; then
    source .env
fi

# 默认值
BACKUP_SOURCE="${BACKUP_SOURCE:-/data}"
BACKUP_LOCAL_PATH="${BACKUP_LOCAL_PATH:-/backups}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
RETENTION_WEEKS="${RETENTION_WEEKS:-12}"
RETENTION_MONTHS="${RETENTION_MONTHS:-6}"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# 检查必要变量
check_env() {
    if [ -z "$RESTIC_PASSWORD" ]; then
        error "RESTIC_PASSWORD not set!"
        exit 1
    fi
    
    if [ -z "$S3_BUCKET" ] && [ -z "$B2_BUCKET" ] && [ -z "$R2_BUCKET" ]; then
        log "No cloud storage configured, using local backup only"
    fi
}

# 初始化 Restic 仓库
init_repo() {
    local repo_path="$1"
    
    if [ ! -d "$repo_path" ]; then
        log "Initializing local repository: $repo_path"
        mkdir -p "$repo_path"
        restic init --repo "$repo_path" || true
    fi
}

# 执行备份
run_backup() {
    local source_dir="$BACKUP_SOURCE"
    local backup_name="${BACKUP_NAME:-$(date +%Y%m%d)}"
    
    log "Starting backup from: $source_dir"
    
    # 本地备份 (副本 1)
    if [ -d "$BACKUP_LOCAL_PATH" ]; then
        local local_repo="$BACKUP_LOCAL_PATH/local"
        init_repo "$local_repo"
        
        log "Backing up to local storage..."
        restic backup "$source_dir" \
            --repo "$local_repo" \
            $BACKUP_EXCLUDES \
            --tag "backup-$backup_name" \
            --tag "type-local"
        
        log "Pruning local repository..."
        restic forget --repo "$local_repo" \
            --keep-daily $RETENTION_DAYS \
            --keep-weekly $RETENTION_WEEKS \
            --keep-monthly $RETENTION_MONTHS \
            --prune
    fi
    
    # S3 备份 (副本 2)
    if [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ]; then
        local s3_repo="s3:$S3_ENDPOINT/$S3_BUCKET$S3_PATH"
        
        log "Backing up to S3..."
        restic backup "$source_dir" \
            --repo "$s3_repo" \
            --password-env RESTIC_PASSWORD \
            $BACKUP_EXCLUDES \
            --tag "backup-$backup_name" \
            --tag "type-s3"
        
        log "Pruning S3 repository..."
        restic forget --repo "$s3_repo" \
            --password-env RESTIC_PASSWORD \
            --keep-daily $RETENTION_DAYS \
            --keep-weekly $RETENTION_WEEKS \
            --keep-monthly $RETENTION_MONTHS \
            --prune
    fi
    
    # B2 备份 (副本 3)
    if [ -n "$B2_ACCOUNT_ID" ]; then
        local b2_repo="b2:$B2_BUCKET:/"
        
        log "Backing up to Backblaze B2..."
        B2_ACCOUNT_ID="$B2_ACCOUNT_ID" \
        B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY" \
        restic backup "$source_dir" \
            --repo "$b2_repo" \
            --password-env RESTIC_PASSWORD \
            $BACKUP_EXCLUDES \
            --tag "backup-$backup_name" \
            --tag "type-b2"
        
        log "Pruning B2 repository..."
        B2_ACCOUNT_ID="$B2_ACCOUNT_ID" \
        B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY" \
        restic forget --repo "$b2_repo" \
            --password-env RESTIC_PASSWORD \
            --keep-daily $RETENTION_DAYS \
            --keep-weekly $RETENTION_WEEKS \
            --keep-monthly $RETENTION_MONTHS \
            --prune
    fi
    
    # R2 备份 (副本 3 替代)
    if [ -n "$R2_ACCOUNT_ID" ]; then
        local r2_repo="s3:$R2_ENDPOINT/$R2_BUCKET"
        
        log "Backing up to Cloudflare R2..."
        AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
        AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
        restic backup "$source_dir" \
            --repo "$r2_repo" \
            --password-env RESTIC_PASSWORD \
            $BACKUP_EXCLUDES \
            --tag "backup-$backup_name" \
            --tag "type-r2"
        
        log "Pruning R2 repository..."
        AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
        AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
        restic forget --repo "$r2_repo" \
            --password-env RESTIC_PASSWORD \
            --keep-daily $RETENTION_DAYS \
            --keep-weekly $RETENTION_WEEKS \
            --keep-monthly $RETENTION_MONTHS \
            --prune
    fi
    
    log "Backup completed successfully!"
    
    # 发送 webhook 通知
    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"success\",\"timestamp\":\"$(date -Iseconds)\",\"source\":\"$source_dir\"}" || true
    fi
}

# 恢复备份
restore_backup() {
    local target_repo="$1"
    local restore_path="${2:-./restore}"
    
    log "Restoring to: $restore_path"
    restic restore latest --repo "$target_repo" --target "$restore_path"
    log "Restore completed!"
}

# 查看快照
list_snapshots() {
    local repo="$1"
    restic snapshots --repo "$repo"
}

# 主程序
case "${1:-backup}" in
    backup)
        check_env
        run_backup
        ;;
    restore)
        restore_backup "$2" "$3"
        ;;
    list)
        list_snapshots "$2"
        ;;
    init)
        check_env
        init_repo "$BACKUP_LOCAL_PATH/local"
        ;;
    *)
        echo "Usage: $0 {backup|restore|list|init}"
        exit 1
        ;;
esac