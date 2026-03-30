#!/bin/bash
# =============================================================================
# HomeLab Stack — Backup to Cloud Script
# =============================================================================
# Syncs local backups from /opt/homelab-backups to cloud storage via Rclone
#
# Usage:
#   ./scripts/backup-to-cloud.sh                    # Interactive mode
#   ./scripts/backup-to-cloud.sh --dry-run         # Test without making changes
#   ./scripts/backup-to-cloud.sh s3-backup         # Sync to specific remote
#   ./scripts/backup-to-cloud.sh gdrive-backup     # Sync to Google Drive
#
# Cron example (daily at 2 AM):
#   0 2 * * * /opt/homelab-stack/scripts/backup-to-cloud.sh >> /var/log/backup-to-cloud.log 2>&1
#
# Payment: https://lll.io/bounty/0xaae0101ac77a2e4e0ea826eb4d309374f029b0a6
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SOURCE="${BACKUP_SOURCE:-/opt/homelab-backups}"
RCLONE_CONFIG="${RCLONE_CONFIG:-$ROOT_DIR/config/rclone/rclone.conf}"
LOG_FILE="${LOG_FILE:-/var/log/backup-to-cloud.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [REMOTE]

Sync local backups to cloud storage using Rclone.

Arguments:
    REMOTE          Rclone remote name to sync to (e.g., s3-backup, gdrive-backup)
                   If not provided, lists available remotes.

Options:
    --dry-run       Show what would be transferred without making changes
    --verbose       Show detailed output
    --help          Show this help message

Examples:
    $(basename "$0")                          # List available remotes
    $(basename "$0") --dry-run s3-backup     # Test sync to S3
    $(basename "$0") gdrive-backup            # Sync to Google Drive
    $(basename "$0") b2-backup                # Sync to Backblaze B2

Environment Variables:
    BACKUP_SOURCE    Source directory (default: /opt/homelab-backups)
    RCLONE_CONFIG    Path to rclone.conf (default: ./config/rclone/rclone.conf)
    LOG_FILE         Log file path (default: /var/log/backup-to-cloud.log)

EOF
}

# Check prerequisites
check_prereqs() {
    if ! command -v rclone &> /dev/null; then
        log_error "rclone not found. Please install rclone first."
        log_info "Install: https://rclone.org/install/"
        exit 1
    fi

    if [ ! -f "$RCLONE_CONFIG" ]; then
        log_error "Rclone config not found at: $RCLONE_CONFIG"
        log_info "Please copy config/rclone/rclone.conf.example to config/rclone/rclone.conf"
        exit 1
    fi

    if [ ! -d "$BACKUP_SOURCE" ]; then
        log_warning "Backup source directory does not exist: $BACKUP_SOURCE"
        log_info "Creating directory..."
        mkdir -p "$BACKUP_SOURCE"
    fi
}

# List available remotes
list_remotes() {
    log_info "Available Rclone remotes:"
    rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null | while read -r remote; do
        echo "  - ${remote%/}"
    done
}

# List available remotes and exit
show_remotes_and_exit() {
    check_prereqs
    echo ""
    log_info "Available cloud backup targets:"
    list_remotes
    echo ""
    log_info "Usage: $(basename "$0") [remote-name]"
    exit 0
}

# Sync backup to remote
sync_to_remote() {
    local remote="$1"
    local dry_run="${DRY_RUN:-}"
    local verbose="${VERBOSE:-}"

    # Validate remote exists
    if ! rclone listremotes --config "$RCLONE_CONFIG" | grep -q "^${remote}:$"; then
        log_error "Remote '$remote' not found in rclone config."
        log_info "Available remotes:"
        list_remotes
        exit 1
    fi

    # Check source has content
    if [ -z "$(ls -A "$BACKUP_SOURCE" 2>/dev/null)" ]; then
        log_warning "Backup source directory is empty: $BACKUP_SOURCE"
        log_info "Nothing to sync."
        exit 0
    fi

    # Build rclone command
    local cmd="rclone sync \"$BACKUP_SOURCE\" \"${remote}:\" --config \"$RCLONE_CONFIG\""
    
    [ -n "$dry_run" ] && cmd="$cmd --dry-run"
    [ -n "$verbose" ] && cmd="$cmd --verbose"
    [ -n "$verbose" ] && cmd="$cmd -v"
    
    cmd="$cmd --log-file \"$LOG_FILE\""
    cmd="$cmd --log-level INFO"
    cmd="$cmd --stats 1s"
    cmd="$cmd --stats-one-line"
    cmd="$cmd --transfers 4"
    cmd="$cmd --checkers 8"
    cmd="$cmd --bwlimit 10M"
    cmd="$cmd --exclude \"*.tmp\""
    cmd="$cmd --exclude \"*.part\""
    cmd="$cmd --exclude \".*\""  # Exclude hidden files

    echo ""
    log_info "Starting backup sync to ${remote}:"
    log_info "  Source: $BACKUP_SOURCE"
    log_info "  Remote: ${remote}:"
    log_info "  Config: $RCLONE_CONFIG"
    [ -n "$dry_run" ] && log_warning "DRY-RUN MODE - No changes will be made"
    echo ""

    # Execute sync
    if eval "$cmd"; then
        log_success "Backup sync completed successfully!"
        
        # Show stats
        if [ -z "$dry_run" ]; then
            echo ""
            log_info "Sync summary:"
            rclone about "${remote}:" --json 2>/dev/null | jq -r '.used, .free, .total' 2>/dev/null || true
        fi
    else
        log_error "Backup sync failed!"
        exit 1
    fi
}

# Main script
main() {
    # Parse arguments
    DRY_RUN=""
    VERBOSE=""
    REMOTE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="1"
                shift
                ;;
            --verbose|-v)
                VERBOSE="1"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                REMOTE="$1"
                shift
                ;;
        esac
    done

    # Check prerequisites
    check_prereqs

    # If no remote specified, show available remotes
    if [ -z "$REMOTE" ]; then
        show_remotes_and_exit
    fi

    # Sync to specified remote
    sync_to_remote "$REMOTE"
}

# Run main function
main "$@"
