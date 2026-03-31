#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & Disaster Recovery Script
# Unified backup management for all stacks
# Usage: backup.sh --target <stack|all> [options]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
ENV_FILE="$BASE_DIR/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Defaults
BACKUP_TARGET="${BACKUP_TARGET:-local}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-changeme}"
RESTIC_REPO="${RESTIC_REPO:-/data/restic}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
LOG_DIR="${LOG_DIR:-/var/log/backup}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[backup]${NC} $*"; }

# Notification via ntfy
notify() {
    local topic="${NTFY_TOPIC:-homelab-backup}"
    local title="$1"; shift
    local msg="$*"
    [[ -n "${NTFY_URL:-}" ]] || return 0
    curl -s -X POST "${NTFY_URL}" \
        -H "Title: $title" \
        -H "Tags: backup" \
        -d "[$title] $msg" > /dev/null 2>&1 || true
}

# Parse arguments
TARGET="all"
DRY_RUN=false
ACTION="backup"
RESTORE_ID=""
STACKS_DIR="$BASE_DIR/stacks"

usage() {
    cat <<EOF
Usage: $0 --target <stack|all> [options]

Options:
  --target all|media|databases|notifications|<stack>   Target stack to backup (default: all)
  --dry-run              Show what would be backed up without executing
  --restore <backup_id>  Restore from specified backup
  --list                 List available backups
  --verify               Verify backup integrity
  --help                 Show this help message

Backup Targets:
  all        Backup all stacks (configs + docker volumes + databases)
  media      Backup media stack only
  databases  Backup databases stack only
  <stack>    Backup a specific stack directory

Environment Variables:
  BACKUP_TARGET       Default backup target (local|s3|b2|sftp|r2)
  BACKUP_DIR         Local backup directory
  RESTIC_PASSWORD    Restic repository password
  RESTIC_REPO        Restic repository URL
  RETENTION_DAYS     Days to keep backups (default: 7)
  NTFY_URL           Ntfy webhook URL for notifications
  NTFY_TOPIC         Ntfy topic (default: homelab-backup)

Examples:
  $0 --target all --dry-run
  $0 --target databases
  $0 --restore 20260327_020000
  $0 --list
  $0 --target all --verify
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --restore) ACTION="restore"; RESTORE_ID="$2"; shift 2 ;;
        --list) ACTION="list"; shift ;;
        --verify) ACTION="verify"; shift ;;
        --help) usage; exit 0 ;;
        *) shift ;;
    esac
done

# Ensure directories exist
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# =============================================================================
# Backup Docker volumes
# =============================================================================
backup_volumes() {
    local stack="$1"
    log_step "Backing up Docker volumes for: $stack"
    local volumes
    volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -v '^$' || true)
    local count=0
    while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        local vol_backup="$BACKUP_DIR/${TIMESTAMP}_vol_${vol}.tar.gz"
        log_info "  Backing up volume: $vol"
        [[ "$DRY_RUN" == true ]] && continue
        docker run --rm \
            -v "${vol}:/data:ro" \
            -v "$BACKUP_DIR:/backup:rw" \
            alpine:3.19 \
            sh -c "tar czf /backup/${TIMESTAMP}_vol_${vol}.tar.gz -C /data . 2>/dev/null" \
            && log_info "    Saved: $vol_backup" \
            || log_warn "    Failed: $vol"
        ((count++)) || true
    done <<< "$volumes"
    log_info "  Volume backups complete ($count volumes)"
}

# =============================================================================
# Backup configs (stacks, scripts, config files)
# =============================================================================
backup_configs() {
    log_step "Backing up configuration files..."
    local config_backup="$BACKUP_DIR/${TIMESTAMP}_configs.tar.gz"
    [[ "$DRY_RUN" == true ]] && log_info "  Would backup configs to: $config_backup" && return
    tar czf "$config_backup" \
        -C "$BASE_DIR" \
        --exclude='stacks/*/data' \
        --exclude='stacks/*/.git' \
        --exclude='*.log' \
        config/ stacks/ scripts/ 2>/dev/null \
        && log_info "  Saved: $config_backup" \
        || log_warn "  Config backup failed"
}

# =============================================================================
# Backup databases
# =============================================================================
backup_databases() {
    log_step "Backing up databases..."
    # PostgreSQL
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'postgres|postgresql' | head -1 || true)
    if [[ -n "$pg_container" ]]; then
        local pg_backup="$BACKUP_DIR/${TIMESTAMP}_postgres_all.sql.gz"
        local pg_pass
        pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
        log_info "  PostgreSQL: $pg_container"
        [[ "$DRY_RUN" == true ]] && continue
        docker exec "$pg_container" \
            sh -c "PGPASSWORD=\"$pg_pass\" pg_dumpall -U postgres" 2>/dev/null \
            | gzip > "$pg_backup" \
            && log_info "    Saved: $pg_backup" \
            || log_warn "    PostgreSQL backup failed"
    fi

    # MariaDB/MySQL
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'mariadb|mysql' | head -1 || true)
    if [[ -n "$mysql_container" ]]; then
        local mysql_backup="$BACKUP_DIR/${TIMESTAMP}_mysql_all.sql.gz"
        local mysql_pass
        mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1 || true)
        log_info "  MySQL/MariaDB: $mysql_container"
        [[ "$DRY_RUN" == true ]] && continue
        docker exec "$mysql_container" \
            sh -c "mysqldump -u root -p'$mysql_pass' --all-databases --single-transaction" 2>/dev/null \
            | gzip > "$mysql_backup" \
            && log_info "    Saved: $mysql_backup" \
            || log_warn "    MySQL backup failed"
    fi

    # Redis
    local redis_container
    redis_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'redis' | head -1 || true)
    if [[ -n "$redis_container" ]]; then
        local redis_backup="$BACKUP_DIR/${TIMESTAMP}_redis.rdb"
        log_info "  Redis: $redis_container"
        [[ "$DRY_RUN" == true ]] && continue
        docker exec "$redis_container" SAVE 2>/dev/null || true
        docker cp "$redis_container:/data/dump.rdb" "$redis_backup" 2>/dev/null \
            && log_info "    Saved: $redis_backup" \
            || log_warn "    Redis backup failed"
    fi
}

# =============================================================================
# Push to cloud via restic
# =============================================================================
backup_to_cloud() {
    log_step "Pushing to cloud backup (restic)..."
    [[ "$DRY_RUN" == true ]] && log_info "  Would run restic backup to $RESTIC_REPO" && return
    if command -v restic &>/dev/null; then
        export RESTIC_PASSWORD
        restic backup "$BACKUP_DIR" \
            --repo "$RESTIC_REPO" \
            --tag "$TARGET" \
            --tag "date=$TIMESTAMP" \
            2>/dev/null \
            && log_info "  Restic backup complete" \
            || log_warn "  Restic backup failed"
    else
        log_warn "  restic not installed, skipping cloud backup"
    fi
}

# =============================================================================
# Cleanup old backups
# =============================================================================
cleanup_old() {
    log_step "Cleaning backups older than ${RETENTION_DAYS} days..."
    [[ "$DRY_RUN" == true ]] && log_info "  Would delete backups in $BACKUP_DIR older than $RETENTION_DAYS days" && return
    find "$BACKUP_DIR" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
    log_info "  Cleanup complete"
}

# =============================================================================
# Generate summary
# =============================================================================
generate_summary() {
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Backup summary:"
    log_info "  Timestamp: $TIMESTAMP"
    log_info "  Location: $BACKUP_DIR"
    log_info "  Total size: $total_size"
    log_info "  Files:"
    ls -lh "$BACKUP_DIR"/${TIMESTAMP}* 2>/dev/null | tail -n +2 | while read -r line; do
        log_info "    $line"
    done
}

# =============================================================================
# Main actions
# =============================================================================
case "$ACTION" in
    backup)
        log_info "Starting backup ===== Target: $TARGET | Dry-run: $DRY_RUN ====="
        notify "Backup Started" "Backup for $TARGET started at $TIMESTAMP"
        backup_configs
        if [[ "$TARGET" == "all" ]]; then
            backup_volumes "all"
            backup_databases
        elif [[ "$TARGET" == "databases" ]]; then
            backup_databases
        else
            backup_volumes "$TARGET"
        fi
        cleanup_old
        generate_summary
        notify "Backup Complete" "Backup for $TARGET completed. Location: $BACKUP_DIR"
        log_info "Backup finished!"
        ;;

    list)
        log_info "Available backups in: $BACKUP_DIR"
        if [[ -d "$BACKUP_DIR" ]]; then
            find "$BACKUP_DIR" -maxdepth 2 -type f -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.rdb" 2>/dev/null \
                | sort | while read -r f; do
                local size=$(du -h "$f" | cut -f1)
                local date=$(date -r "$f" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
                echo "  $date | $size | $(basename "$f")"
            done
        else
            log_warn "No backups found"
        fi
        ;;

    verify)
        log_step "Verifying backup integrity..."
        local errors=0
        while IFS= read -r f; do
            [[ -z "$f" || "$f" == *".sha256"* ]] && continue
            if [[ "$f" == *.tar.gz ]]; then
                tar tzf "$f" &>/dev/null \
                    && log_info "  OK: $(basename "$f")" \
                    || { log_error "  CORRUPT: $(basename "$f")"; ((errors++)) || true; }
            elif [[ "$f" == *.sql.gz ]]; then
                gzip -t "$f" 2>/dev/null \
                    && log_info "  OK: $(basename "$f")" \
                    || { log_error "  CORRUPT: $(basename "$f")"; ((errors++)) || true; }
            fi
        done < <(find "$BACKUP_DIR" -type f 2>/dev/null)
        if [[ "$errors" -eq 0 ]]; then
            log_info "All backups verified successfully!"
            notify "Backup Verified" "All backups in $BACKUP_DIR passed integrity check"
        else
            log_error "Verification failed: $errors corrupt file(s)"
            notify "Backup VERIFY FAILED" "$errors files are corrupt in $BACKUP_DIR"
        fi
        ;;

    restore)
        log_info "Restore requested: $RESTORE_ID"
        log_warn "Restore is interactive. Check docs/disaster-recovery.md for step-by-step guide."
        log_info "To restore configs: tar xzf ${BACKUP_DIR}/${RESTORE_ID}_configs.tar.gz -C $BASE_DIR"
        ;;
esac
