#!/bin/bash

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config/backup.conf}"
LOG_FILE="${LOG_FILE:-/var/log/backup.log}"
LOCK_FILE="/var/run/backup.lock"

# Default values
DRY_RUN=false
VERBOSE=false
REPOSITORY=""
OPERATION=""
BACKUP_TARGETS=()
EXCLUDE_PATTERNS=()
INCLUDE_PATTERNS=()

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Warning: Configuration file not found at $CONFIG_FILE"
    fi
    
    # Set defaults if not configured
    BACKUP_RETENTION_POLICY=${BACKUP_RETENTION_POLICY:-"--keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 2"}
    BACKUP_EXCLUDE_FILE=${BACKUP_EXCLUDE_FILE:-"${SCRIPT_DIR}/../config/backup-exclude.txt"}
    BACKUP_INCLUDE_FILE=${BACKUP_INCLUDE_FILE:-"${SCRIPT_DIR}/../config/backup-include.txt"}
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    if [[ "$VERBOSE" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

# Lock management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "ERROR" "Another backup process is running (PID: $pid)"
            exit 1
        else
            log "INFO" "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM
}

# Repository initialization
init_repository() {
    local repo="$1"
    
    if ! restic -r "$repo" snapshots >/dev/null 2>&1; then
        log "INFO" "Initializing repository: $repo"
        if [[ "$DRY_RUN" == "false" ]]; then
            restic -r "$repo" init
        else
            log "INFO" "[DRY-RUN] Would initialize repository: $repo"
        fi
    fi
}

# S3 repository setup
setup_s3_repo() {
    local config="$1"
    eval "$config"
    
    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
    export RESTIC_REPOSITORY="s3:${S3_ENDPOINT}/${S3_BUCKET}"
    export RESTIC_PASSWORD="$S3_PASSWORD"
    
    echo "$RESTIC_REPOSITORY"
}

# Backblaze B2 repository setup
setup_b2_repo() {
    local config="$1"
    eval "$config"
    
    export B2_ACCOUNT_ID="$B2_ACCOUNT_ID"
    export B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY"
    export RESTIC_REPOSITORY="b2:${B2_BUCKET}"
    export RESTIC_PASSWORD="$B2_PASSWORD"
    
    echo "$RESTIC_REPOSITORY"
}

# SFTP repository setup
setup_sftp_repo() {
    local config="$1"
    eval "$config"
    
    export RESTIC_REPOSITORY="sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}"
    export RESTIC_PASSWORD="$SFTP_PASSWORD"
    
    echo "$RESTIC_REPOSITORY"
}

# Local repository setup
setup_local_repo() {
    local config="$1"
    eval "$config"
    
    export RESTIC_REPOSITORY="$LOCAL_PATH"
    export RESTIC_PASSWORD="$LOCAL_PASSWORD"
    
    # Ensure directory exists
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$LOCAL_PATH"
    fi
    
    echo "$RESTIC_REPOSITORY"
}

# Setup repository based on type
setup_repository() {
    local type="$1"
    local config="$2"
    
    case "$type" in
        "s3")
            setup_s3_repo "$config"
            ;;
        "b2")
            setup_b2_repo "$config"
            ;;
        "sftp")
            setup_sftp_repo "$config"
            ;;
        "local")
            setup_local_repo "$config"
            ;;
        *)
            log "ERROR" "Unknown repository type: $type"
            exit 1
            ;;
    esac
}

# Load include/exclude patterns
load_patterns() {
    # Load exclude patterns
    if [[ -f "$BACKUP_EXCLUDE_FILE" ]]; then
        while IFS= read -r pattern; do
            [[ -n "$pattern" && ! "$pattern" =~ ^# ]] && EXCLUDE_PATTERNS+=("--exclude=$pattern")
        done < "$BACKUP_EXCLUDE_FILE"
    fi
    
    # Load include patterns
    if [[ -f "$BACKUP_INCLUDE_FILE" ]]; then
        while IFS= read -r pattern; do
            [[ -n "$pattern" && ! "$pattern" =~ ^# ]] && INCLUDE_PATTERNS+=("$pattern")
        done < "$BACKUP_INCLUDE_FILE"
    fi
    
    # Default includes if none specified
    if [[ ${#INCLUDE_PATTERNS[@]} -eq 0 ]]; then
        INCLUDE_PATTERNS+=("/etc" "/home" "/opt" "/var/lib" "/usr/local")
    fi
}

# Perform backup
perform_backup() {
    local repo_type="$1"
    local repo_config="$2"
    local repo_name="$3"
    
    log "INFO" "Starting backup to $repo_name ($repo_type)"
    
    local repo_url
    repo_url=$(setup_repository "$repo_type" "$repo_config")
    
    # Initialize repository if needed
    init_repository "$repo_url"
    
    # Build restic command
    local restic_cmd=(
        "restic" "-r" "$repo_url" "backup"
        "--tag" "$(hostname)"
        "--tag" "$(date +%Y-%m-%d)"
    )
    
    # Add exclude patterns
    restic_cmd+=("${EXCLUDE_PATTERNS[@]}")
    
    # Add include patterns
    restic_cmd+=("${INCLUDE_PATTERNS[@]}")
    
    # Add verbose flag if enabled
    if [[ "$VERBOSE" == "true" ]]; then
        restic_cmd+=("--verbose")
    fi
    
    # Execute backup
    if [[ "$DRY_RUN" == "false" ]]; then
        log "INFO" "Executing: ${restic_cmd[*]}"
        if "${restic_cmd[@]}"; then
            log "INFO" "Backup completed successfully for $repo_name"
        else
            log "ERROR" "Backup failed for $repo_name"
            return 1
        fi
    else
        log "INFO" "[DRY-RUN] Would execute: ${restic_cmd[*]}"
    fi
    
    # Cleanup old snapshots
    if [[ "$DRY_RUN" == "false" ]]; then
        log "INFO" "Cleaning up old snapshots for $repo_name"
        eval "restic -r \"$repo_url\" forget $BACKUP_RETENTION_POLICY --prune"
    else
        log "INFO" "[DRY-RUN] Would cleanup old snapshots: restic forget $BACKUP_RETENTION_POLICY --prune"
    fi
}

# List snapshots
list_snapshots() {
    local repo_type="$1"
    local repo_config="$2"
    local repo_name="$3"
    
    log "INFO" "Listing snapshots for $repo_name ($repo_type)"
    
    local repo_url
    repo_url=$(setup_repository "$repo_type" "$repo_config")
    
    restic -r "$repo_url" snapshots
}

# Verify backup
verify_backup() {
    local repo_type="$1"
    local repo_config="$2"
    local repo_name="$3"
    
    log "INFO" "Verifying backup for $repo_name ($repo_type)"
    
    local repo_url
    repo_url=$(setup_repository "$repo_type" "$repo_config")
    
    if restic -r "$repo_url" check; then
        log "INFO" "Verification completed successfully for $repo_name"
    else
        log "ERROR" "Verification failed for $repo_name"
        return 1
    fi
}

# Restore backup
restore_backup() {
    local repo_type="$1"
    local repo_config="$2"
    local repo_name="$3"
    local snapshot_id="$4"
    local restore_path="$5"
    
    log "INFO" "Restoring from $repo_name ($repo_type) snapshot $snapshot_id to $restore_path"
    
    local repo_url
    repo_url=$(setup_repository "$repo_type" "$repo_config")
    
    # Create restore directory
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$restore_path"
        if restic -r "$repo_url" restore "$snapshot_id" --target "$restore_path"; then
            log "INFO" "Restore completed successfully for $repo_name"
        else
            log "ERROR" "Restore failed for $repo_name"
            return 1
        fi
    else
        log "INFO" "[DRY-RUN] Would restore snapshot $snapshot_id to $restore_path"
    fi
}

# Process all configured repositories
process_repositories() {
    local operation="$1"
    local snapshot_id="${2:-}"
    local restore_path="${3:-}"
    
    # Process each repository type
    for repo_type in s3 b2 sftp local; do
        local repo_var="${repo_type^^}_REPOSITORIES"
        if [[ -n "${!repo_var:-}" ]]; then
            local repos_config="${!repo_var}"
            local repo_count=1
            
            # Split multiple repositories
            while IFS= read -r repo_config; do
                [[ -n "$repo_config" ]] || continue
                
                local repo_name="${repo_type}_${repo_count}"
                
                case "$operation" in
                    "backup")
                        perform_backup "$repo_type" "$repo_config" "$repo_name"
                        ;;
                    "list")
                        list_snapshots "$repo_type" "$repo_config" "$repo_name"
                        ;;
                    "verify")
                        verify_backup "$repo_type" "$repo_config" "$repo_name"
                        ;;
                    "restore")
                        restore_backup "$repo_type" "$repo_config" "$repo_name" "$snapshot_id" "$restore_path"
                        ;;
                esac
                
                ((repo_count++))
            done <<< "$repos_config"
        fi
    done
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] OPERATION [ARGS]

OPERATIONS:
    backup              Perform backup to all configured repositories
    restore SNAPSHOT    Restore from snapshot (requires --repo and --target)
    list                List all snapshots in repositories
    verify              Verify integrity of all repositories

OPTIONS:
    -c, --config FILE   Configuration file (default: $CONFIG_FILE)
    -r, --repo REPO     Specific repository name for restore operation
    -t, --target PATH   Target path for restore operation
    -n, --dry-run       Show what would be done without executing
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    $0 backup
    $0 --dry-run backup
    $0 list
    $0 verify
    $0 restore abc123def --repo s3_1 --target /tmp/restore
    $0 --verbose --config /etc/backup.conf backup

REPOSITORY CONFIGURATION:
    Configuration file should define repository settings:
    
    # S3 repositories
    S3_REPOSITORIES="
    S3_ACCESS_KEY=key1 S3_SECRET_KEY=secret1 S3_ENDPOINT=s3.amazonaws.com S3_BUCKET=backup1 S3_PASSWORD=pass1
    S3_ACCESS_KEY=key2 S3_SECRET_KEY=secret2 S3_ENDPOINT=s3.amazonaws.com S3_BUCKET=backup2 S3_PASSWORD=pass2
    "
    
    # Backblaze B2 repositories
    B2_REPOSITORIES="
    B2_ACCOUNT_ID=id1 B2_ACCOUNT_KEY=key1 B2_BUCKET=bucket1 B2_PASSWORD=pass1
    "
    
    # SFTP repositories
    SFTP_REPOSITORIES="
    SFTP_USER=user1 SFTP_HOST=server1.com SFTP_PATH=/backup SFTP_PASSWORD=pass1
    "
    
    # Local repositories
    LOCAL_REPOSITORIES="
    LOCAL_PATH=/mnt/backup1 LOCAL_PASSWORD=pass1
    LOCAL_PATH=/mnt/backup2 LOCAL_PASSWORD=pass2
    "

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -r|--repo)
                REPOSITORY="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_PATH="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            backup|restore|list|verify)
                OPERATION="$1"
                shift
                break
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Handle remaining arguments for restore operation
    if [[ "$OPERATION" == "restore" && $# -gt 0 ]]; then
        SNAPSHOT_ID="$1"
        shift
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Validate operation
    if [[ -z "$OPERATION" ]]; then
        log "ERROR" "No operation specified"
        usage
        exit 1
    fi
    
    # Load configuration
    load_config
    
    # Load backup patterns
    load_patterns
    
    # Validate restore operation requirements
    if [[ "$OPERATION" == "restore" ]]; then
        if [[ -z "$SNAPSHOT_ID" || -z "$TARGET_PATH" ]]; then
            log "ERROR" "Restore operation requires snapshot ID and target path"
            usage
            exit 1
        fi
    fi
    
    # Acquire lock for backup operations
    if [[ "$OPERATION" == "backup" ]]; then
        acquire_lock
    fi
    
    log "INFO" "Starting $OPERATION operation"
    
    # Execute operation
    case "$OPERATION" in
        "backup")
            process_repositories "backup"
            ;;
        "restore")
            process_repositories "restore" "$SNAPSHOT_ID" "$TARGET_PATH"
            ;;
        "list")
            process_repositories "list"
            ;;
        "verify")
            process_repositories "verify"
            ;;
    esac
    
    log "INFO" "Operation $OPERATION completed"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v restic >/dev/null 2>&1; then
        missing_deps+=("restic")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "INFO" "Please install missing dependencies and try again"
        exit 1
    fi
}

# Initialize
check_dependencies
main "$@"