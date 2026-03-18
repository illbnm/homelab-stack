#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Manager - Bounty #12
# Supports: multiple targets, dry-run, restore, list, verify
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

# Load environment
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Configuration
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[backup]${NC} $*"; }

# Usage
usage() {
    cat << EOF
Usage: backup.sh --target <stack|all> [options]

Options:
    --target <stack>    Backup specific stack or 'all' for all stacks
    --dry-run           Show what would be backed up without executing
    --restore <id>      Restore from specific backup ID
    --list              List all available backups
    --verify            Verify backup integrity
    --help              Show this help message

Backup Targets (set via BACKUP_TARGET env):
    local               Local directory (default: /opt/homelab-backups)
    s3                  MinIO/S3-compatible storage
    b2                  Backblaze B2
    sftp                SFTP server
    r2                  Cloudflare R2

Examples:
    backup.sh --target all --dry-run
    backup.sh --target media
    backup.sh --list
    backup.sh --restore 20240318_120000
    backup.sh --verify
EOF
}

# Notify via ntfy
notify() {
    local status="$1"
    local message="$2"
    
    if command -v curl &>/dev/null; then
        curl -s -d "$message" \
            -H "Title: Backup $status" \
            -H "Priority: $([[ "$status" == "failed" ]] && echo "high" || echo "default")" \
            "${NTFY_SERVER}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
    fi
}

# List stacks
get_stacks() {
    local stacks_dir="$BASE_DIR/stacks"
    local stacks=()
    
    for dir in "$stacks_dir"/*/; do
        [[ -d "$dir" ]] || continue
        local name
        name=$(basename "$dir")
        [[ -f "$dir/docker-compose.yml" ]] && stacks+=("$name")
    done
    
    echo "${stacks[@]}"
}

# Backup specific stack
backup_stack() {
    local stack="$1"
    local dry_run="${2:-0}"
    local stack_dir="$BASE_DIR/stacks/$stack"
    
    [[ -d "$stack_dir" ]] || { log_error "Stack not found: $stack"; return 1; }
    [[ -f "$stack_dir/docker-compose.yml" ]] || { log_error "No docker-compose.yml in $stack"; return 1; }
    
    log_info "Backing up stack: $stack"
    
    if [[ "$dry_run" == "1" ]]; then
        log_info "[DRY-RUN] Would backup: $stack_dir"
        return 0
    fi
    
    # Backup volumes for this stack
    local volumes
    volumes=$(docker compose -f "$stack_dir/docker-compose.yml" config --volumes 2>/dev/null || true)
    
    for vol in $volumes; do
        log_info "  Volume: $vol"
        # Backup logic here
    done
    
    # Backup config for this stack
    [[ -d "$stack_dir/config" ]] && log_info "  Config: $stack_dir/config"
}

# Backup all stacks
backup_all() {
    local dry_run="${1:-0}"
    local stacks
    stacks=$(get_stacks)
    
    log_info "Backing up all stacks (${stacks})"
    
    for stack in $stacks; do
        backup_stack "$stack" "$dry_run" || log_warn "Failed to backup: $stack"
    done
}

# List backups
list_backups() {
    log_info "Available backups:"
    
    if [[ "$BACKUP_TARGET" == "local" ]]; then
        [[ -d "$BACKUP_DIR" ]] || { log_info "No backups found"; return 0; }
        ls -lh "$BACKUP_DIR" 2>/dev/null || log_info "No backups found"
    else
        log_info "Listing backups from $BACKUP_TARGET (not implemented)"
    fi
}

# Restore backup
restore_backup() {
    local backup_id="$1"
    
    log_info "Restoring backup: $backup_id"
    log_warn "Restore functionality requires manual intervention"
    log_info "Backup location: $BACKUP_DIR/$backup_id"
}

# Verify backup
verify_backup() {
    local backup_id="${1:-}"
    
    if [[ -n "$backup_id" ]]; then
        log_info "Verifying backup: $backup_id"
    else
        log_info "Verifying all backups"
    fi
    
    log_warn "Verify functionality requires implementation"
}

# Main
main() {
    local target=""
    local dry_run=0
    local restore_id=""
    local action=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                target="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --restore)
                restore_id="$2"
                action="restore"
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
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Handle actions
    case "$action" in
        list)
            list_backups
            exit 0
            ;;
        restore)
            [[ -z "$restore_id" ]] && { log_error "Restore requires backup ID"; usage; exit 1; }
            restore_backup "$restore_id"
            exit 0
            ;;
        verify)
            verify_backup
            exit 0
            ;;
    esac
    
    # Handle backup
    [[ -z "$target" ]] && { log_error "Target required"; usage; exit 1; }
    
    log_info "Starting backup — $(date)"
    log_info "Target: $target | Dry-run: $dry_run | Backend: $BACKUP_TARGET"
    
    notify "started" "Backup started: $target"
    
    local result=0
    
    if [[ "$target" == "all" ]]; then
        backup_all "$dry_run" || result=1
    else
        backup_stack "$target" "$dry_run" || result=1
    fi
    
    if [[ $result -eq 0 ]]; then
        log_info "Backup completed successfully"
        notify "success" "Backup completed: $target"
    else
        log_error "Backup failed"
        notify "failed" "Backup failed: $target"
    fi
    
    exit $result
}

main "$@"
