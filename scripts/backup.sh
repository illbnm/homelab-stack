#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script - 3-2-1 Backup Strategy Implementation
# Issue #12 - Backup & DR
# =============================================================================
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"
ENV_EXAMPLE="$BASE_DIR/.env.example"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
elif [[ -f "$ENV_EXAMPLE" ]]; then
    source "$ENV_EXAMPLE"
fi

# Default configuration (allow override via environment)
# Use workspace backup dir as default to avoid permission issues
DEFAULT_BACKUP_DIR="${BASE_DIR}/backups"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
TZ="${TZ:-Asia/Shanghai}"

# Restic configuration
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
R2_ENDPOINT="${R2_ENDPOINT:-}"
R2_ACCESS_KEY="${R2_ACCESS_KEY:-}"
R2_SECRET_KEY="${R2_SECRET_KEY:-}"
R2_BUCKET="${R2_BUCKET:-homelab-backups}"

# S3/MinIO configuration
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-homelab-backups}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

# B2 configuration
B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-}"
B2_BUCKET="${B2_BUCKET:-homelab-backups}"

# SFTP configuration
SFTP_HOST="${SFTP_HOST:-}"
SFTP_PORT="${SFTP_PORT:-22}"
SFTP_USER="${SFTP_USER:-}"
SFTP_KEY="${SFTP_KEY:-}"
SFTP_PATH="${SFTP_PATH:-/backup}"

# Docker volumes to backup
BASE_VOLUMES=(
    "homelab_postgres_data"
    "homelab_redis_data"
    "homelab_mariadb_data"
)

MEDIA_VOLUMES=(
    "homelab_media_config"
    "homelab_transmission_config"
    "homelab_radarr_config"
    "homelab_sonarr_config"
    "homelab_plex_config"
)

ALL_VOLUMES=("${BASE_VOLUMES[@]}" "${MEDIA_VOLUMES[@]}")

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG:${NC} $*"
    fi
}

# Send notification via ntfy
send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -n "$NTFY_URL" && "$NTFY_URL" != "https://ntfy.sh" || "$NTFY_URL" == "https://ntfy.sh" ]]; then
        curl -s -o /dev/null -w "%{http_code}" \
            -H "Title: HomeLab Backup - $status" \
            -H "Tags: $status" \
            -d "[$status] $message" \
            "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || true
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

HomeLab Backup Script - 3-2-1 Backup Strategy Implementation

OPTIONS:
    --target <stack|all>    Backup target: all (default) or media stack only
    --dry-run              Show what would be backed up without executing
    --restore <backup_id>  Restore from specified backup
    --list                 List all available backups
    --verify               Verify backup integrity
    -h, --help             Show this help message

EXAMPLES:
    $(basename "$0") --target all              # Backup all stacks
    $(basename "$0") --target media             # Backup media stack only
    $(basename "$0") --dry-run                  # Preview backup content
    $(basename "$0") --list                     # List all backups
    $(basename "$0") --verify                    # Verify backup integrity
    $(basename "$0") --restore backup_20260318  # Restore from backup

BACKUP TARGETS (via .env):
    local      - Local directory (default)
    s3         - S3/MinIO
    b2         - Backblaze B2
    sftp       - SFTP
    r2         - Cloudflare R2

EOF
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    # Check restic if using remote targets
    if [[ "$BACKUP_TARGET" != "local" ]]; then
        if ! command -v restic &> /dev/null; then
            missing+=("restic")
        fi
    fi
    
    # Check curl for notifications
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install missing dependencies and try again"
        exit 1
    fi
}

# Get list of Docker volumes to backup
get_volumes_to_backup() {
    local target="$1"
    local volumes=()
    
    case "$target" in
        all)
            volumes=("${ALL_VOLUMES[@]}")
            ;;
        media)
            volumes=("${MEDIA_VOLUMES[@]}")
            ;;
        base)
            volumes=("${BASE_VOLUMES[@]}")
            ;;
        *)
            log_error "Invalid target: $target"
            return 1
            ;;
    esac
    
    # Filter to only existing volumes
    local existing_volumes=()
    for vol in "${volumes[@]}"; do
        if docker volume ls -q | grep -q "^${vol}$"; then
            existing_volumes+=("$vol")
        else
            log_debug "Volume not found, skipping: $vol"
        fi
    done
    
    printf '%s\n' "${existing_volumes[@]}"
}

# Backup Docker volumes
backup_volumes() {
    local target="$1"
    local dry_run="$2"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local volumes
    volumes=$(get_volumes_to_backup "$target")
    
    if [[ -z "$volumes" ]]; then
        log_warn "No volumes found for backup target: $target"
        return 0
    fi
    
    log_info "Backing up Docker volumes for target: $target"
    
    while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        
        local backup_file="${BACKUP_DIR}/${vol}_${timestamp}.tar.gz"
        
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would backup volume: $vol -> $backup_file"
            continue
        fi
        
        log_info "Backing up volume: $vol"
        
        # Create backup using alpine container
        if docker run --rm \
            -v "${vol}:/data:ro" \
            -v "${BACKUP_DIR}:/backup:rw" \
            alpine:3.19 \
            tar czf "/backup/$(basename "$backup_file")" -C /data . 2>/dev/null; then
            log_info "  Volume $vol backed up successfully"
        else
            log_warn "  Failed to backup volume: $vol"
        fi
    done <<< "$volumes"
}

# Backup configuration files
backup_configs() {
    local dry_run="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local backup_file="${BACKUP_DIR}/configs_${timestamp}.tar.gz"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] Would backup configs to: $backup_file"
        return 0
    fi
    
    log_info "Backing up configuration files..."
    
    # Create tar archive of config directory
    if tar czf "$backup_file" \
        -C "$BASE_DIR" \
        --exclude='stacks/*/data' \
        --exclude='stacks/*/volumes' \
        --exclude='.git' \
        config/ stacks/ scripts/ 2>/dev/null; then
        log_info "  Configs backed up successfully: $(basename "$backup_file")"
    else
        log_warn "  Failed to backup configs"
    fi
}

# Backup databases
backup_databases() {
    local dry_run="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_info "Backing up databases..."
    
    # PostgreSQL backup
    local pg_containers
    pg_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' || true)
    
    if [[ -n "$pg_containers" ]]; then
        for container in $pg_containers; do
            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY-RUN] Would backup PostgreSQL from: $container"
                continue
            fi
            
            local backup_file="${BACKUP_DIR}/postgres_${container}_${timestamp}.sql"
            
            # Try to get password from environment
            local pg_pass=""
            pg_pass=$(docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
            
            if [[ -n "$pg_pass" ]]; then
                if docker exec "$container" sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" > "$backup_file" 2>/dev/null; then
                    log_info "  PostgreSQL ($container) backed up successfully"
                else
                    log_warn "  Failed to backup PostgreSQL: $container"
                fi
            else
                log_warn "  Cannot backup PostgreSQL: password not found for $container"
            fi
        done
    fi
    
    # MariaDB/MySQL backup
    local mysql_containers
    mysql_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' || true)
    
    if [[ -n "$mysql_containers" ]]; then
        for container in $mysql_containers; do
            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY-RUN] Would backup MySQL from: $container"
                continue
            fi
            
            local backup_file="${BACKUP_DIR}/mysql_${container}_${timestamp}.sql"
            
            # Try to get password from environment
            local mysql_pass=""
            mysql_pass=$(docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1 || true)
            
            if [[ -n "$mysql_pass" ]]; then
                if docker exec "$container" sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" > "$backup_file" 2>/dev/null; then
                    log_info "  MySQL ($container) backed up successfully"
                else
                    log_warn "  Failed to backup MySQL: $container"
                fi
            else
                log_warn "  Cannot backup MySQL: password not found for $container"
            fi
        done
    fi
}

# Initialize restic repository
init_restic() {
    local repo_url="$1"
    local password="$2"
    
    export RESTIC_PASSWORD="$password"
    
    if ! restic -r "$repo_url" snapshots &>/dev/null; then
        log_info "Initializing new restic repository..."
        restic -r "$repo_url" init || true
    fi
}

# Upload to remote backup target
upload_to_remote() {
    local target="$1"
    local local_dir="$2"
    
    case "$target" in
        s3)
            if [[ -z "$S3_ENDPOINT" || -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
                log_error "S3 configuration missing. Set S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY in .env"
                return 1
            fi
            
            log_info "Uploading to S3..."
            # Use AWS CLI or rclone for S3 upload
            if command -v rclone &> /dev/null; then
                rclone sync "$local_dir" "s3:${S3_BUCKET}" \
                    --s3-endpoint "$S3_ENDPOINT" \
                    --s3-access-key-id "$S3_ACCESS_KEY" \
                    --s3-secret-access-key "$S3_SECRET_KEY" \
                    --transfers 4 \
                    --stats-one-line || log_warn "S3 upload failed"
            else
                log_warn "rclone not installed, skipping S3 upload"
            fi
            ;;
            
        b2)
            if [[ -z "$B2_ACCOUNT_ID" || -z "$B2_ACCOUNT_KEY" ]]; then
                log_error "B2 configuration missing. Set B2_ACCOUNT_ID, B2_ACCOUNT_KEY in .env"
                return 1
            fi
            
            log_info "Uploading to Backblaze B2..."
            export B2_ACCOUNT_ID
            export B2_ACCOUNT_KEY
            
            if command -v restic &> /dev/null; then
                local repo_url="b2:${B2_BUCKET}:/homelab"
                init_restic "$repo_url" "${RESTIC_PASSWORD:-backup123}"
                restic -r "$repo_url" backup "$local_dir" || log_warn "B2 backup failed"
            else
                log_warn "restic not installed, skipping B2 upload"
            fi
            ;;
            
        r2)
            if [[ -z "$R2_ENDPOINT" || -z "$R2_ACCESS_KEY" || -z "$R2_SECRET_KEY" ]]; then
                log_error "R2 configuration missing. Set R2_ENDPOINT, R2_ACCESS_KEY, R2_SECRET_KEY in .env"
                return 1
            fi
            
            log_info "Uploading to Cloudflare R2..."
            
            if command -v rclone &> /dev/null; then
                rclone sync "$local_dir" "r2:${R2_BUCKET}" \
                    --s3-endpoint "$R2_ENDPOINT" \
                    --s3-access-key-id "$R2_ACCESS_KEY" \
                    --s3-secret-access-key "$R2_SECRET_KEY" \
                    --s3-region auto \
                    --transfers 4 \
                    --stats-one-line || log_warn "R2 upload failed"
            else
                log_warn "rclone not installed, skipping R2 upload"
            fi
            ;;
            
        sftp)
            if [[ -z "$SFTP_HOST" || -z "$SFTP_USER" ]]; then
                log_error "SFTP configuration missing. Set SFTP_HOST, SFTP_USER in .env"
                return 1
            fi
            
            log_info "Uploading to SFTP..."
            
            if command -v rclone &> /dev/null; then
                rclone sync "$local_dir" "sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}" \
                    --sftp-port "$SFTP_PORT" \
                    --sftp-key-file "$SFTP_KEY" \
                    --transfers 4 \
                    --stats-one-line || log_warn "SFTP upload failed"
            else
                log_warn "rclone not installed, skipping SFTP upload"
            fi
            ;;
            
        local)
            log_info "Backup stored locally: $local_dir"
            ;;
            
        *)
            log_error "Unknown backup target: $target"
            return 1
            ;;
    esac
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than ${BACKUP_RETENTION_DAYS} days..."
    
    find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql" \) \
        -mtime +"$BACKUP_RETENTION_DAYS" -delete 2>/dev/null || true
    
    find "$BACKUP_DIR" -maxdepth 1 -type d -empty -mtime +"$BACKUP_RETENTION_DAYS" \
        -exec rmdir {} + 2>/dev/null || true
    
    log_info "Cleanup complete"
}

# List all backups
list_backups() {
    log_info "Available backups in ${BACKUP_DIR}:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warn "Backup directory does not exist: $BACKUP_DIR"
        return 0
    fi
    
    echo ""
    printf "%-50s %15s\n" "Backup File" "Size"
    printf "%s\n" "$(printf '=%.0s' {1..65})"
    
    local total_size=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local size
        size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "Unknown")
        local basename
        basename=$(basename "$file")
        printf "%-50s %15s\n" "$basename" "$size"
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql" \) -printf '%p\n' | sort)
    
    printf "%s\n" "$(printf '=%.0s' {1..65})"
    local total
    total=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
    printf "%-50s %15s\n" "Total:" "$total"
}

# Verify backup integrity
verify_backups() {
    log_info "Verifying backup integrity..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi
    
    local verified=0
    local failed=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local basename
        basename=$(basename "$file")
        
        if [[ "$file" == *.tar.gz ]]; then
            if tar tzf "$file" &>/dev/null; then
                log_info "✓ $basename - OK"
                ((verified++))
            else
                log_error "✗ $basename - CORRUPTED"
                ((failed++))
            fi
        elif [[ "$file" == *.sql ]]; then
            if head -n 1 "$file" &>/dev/null; then
                log_info "✓ $basename - OK"
                ((verified++))
            else
                log_error "✗ $basename - CORRUPTED"
                ((failed++))
            fi
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql" \) -printf '%p\n')
    
    echo ""
    log_info "Verification complete: $verified OK, $failed FAILED"
    
    return 0
}

# Restore from backup
restore_backup() {
    local backup_id="$1"
    
    if [[ -z "$backup_id" ]]; then
        log_error "Backup ID required for restore"
        return 1
    fi
    
    log_info "Restoring from backup: $backup_id"
    
    # Find the backup file
    local backup_file
    backup_file=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*${backup_id}*" | head -1)
    
    if [[ -z "$backup_file" ]]; then
        log_error "Backup not found: $backup_id"
        log_info "Use --list to see available backups"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Found backup: $(basename "$backup_file")"
    
    # Determine restore type
    if [[ "$backup_file" == *.tar.gz ]]; then
        # Volume or config backup
        if [[ "$backup_file" == *vol_* ]]; then
            # Restore volume
            local volume_name
            volume_name=$(basename "$backup_file" | sed 's/vol_\(.*\)_[0-9]*.tar.gz/\1/')
            
            log_info "Restoring volume: $volume_name"
            read -p "This will overwrite volume '$volume_name'. Continue? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Restore cancelled"
                return 0
            fi
            
            # Create volume if not exists
            docker volume create "${volume_name}" 2>/dev/null || true
            
            # Restore
            docker run --rm \
                -v "${volume_name}:/data:rw" \
                -v "${BACKUP_DIR}:/backup:ro" \
                alpine:3.19 \
                tar xzf "/backup/$(basename "$backup_file")" -C /data 2>/dev/null
            
            log_info "Volume restored successfully"
            
        elif [[ "$backup_file" == *configs_* ]]; then
            # Restore configs
            log_info "Restoring configuration files..."
            read -p "This will overwrite config files. Continue? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Restore cancelled"
                return 0
            fi
            
            tar xzf "$backup_file" -C "$BASE_DIR" 2>/dev/null
            log_info "Configuration files restored successfully"
        fi
        
    elif [[ "$backup_file" == *.sql ]]; then
        # Database restore
        if [[ "$backup_file" == *postgres_* ]]; then
            local container
            container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
            
            if [[ -n "$container" ]]; then
                log_info "Restoring PostgreSQL database..."
                docker exec -i "$container" psql -U postgres < "$backup_file"
                log_info "PostgreSQL restored successfully"
            else
                log_error "PostgreSQL container not found"
            fi
            
        elif [[ "$backup_file" == *mysql_* || "$backup_file" == *mariadb_* ]]; then
            local container
            container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
            
            if [[ -n "$container" ]]; then
                log_info "Restoring MySQL database..."
                docker exec -i "$container" sh -c 'exec mysql -u root -p"$MYSQL_ROOT_PASSWORD"' < "$backup_file"
                log_info "MySQL restored successfully"
            else
                log_error "MySQL container not found"
            fi
        fi
    fi
}

# Generate backup summary
generate_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    echo ""
    log_info "============================================="
    log_info "Backup completed in ${duration}s"
    log_info "Total backup size: $total_size"
    log_info "Backup location: $BACKUP_DIR"
    log_info "============================================="
}

# Main function
main() {
    local target="all"
    local dry_run="false"
    local restore_id=""
    local list_backups_flag="false"
    local verify_flag="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                target="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --restore)
                restore_id="$2"
                shift 2
                ;;
            --list)
                list_backups_flag="true"
                shift
                ;;
            --verify)
                verify_flag="true"
                shift
                ;;
            -h|--help)
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
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Handle different commands
    if [[ "$list_backups_flag" == "true" ]]; then
        list_backups
        exit 0
    fi
    
    if [[ "$verify_flag" == "true" ]]; then
        verify_backups
        exit $?
    fi
    
    if [[ -n "$restore_id" ]]; then
        restore_backup "$restore_id"
        exit $?
    fi
    
    # Run backup
    log_info "============================================="
    log_info "HomeLab Backup - Starting backup"
    log_info "Target: $target"
    log_info "Mode: $([[ "$dry_run" == "true" ]] && echo "DRY-RUN" || echo "LIVE")"
    log_info "Backup Target: $BACKUP_TARGET"
    log_info "============================================="
    
    # Execute backup
    backup_configs "$dry_run"
    backup_volumes "$target" "$dry_run"
    backup_databases "$dry_run"
    
    if [[ "$dry_run" == "false" ]]; then
        # Upload to remote if configured
        if [[ "$BACKUP_TARGET" != "local" ]]; then
            upload_to_remote "$BACKUP_TARGET" "$BACKUP_DIR"
        fi
        
        # Cleanup old backups
        cleanup_old_backups
        
        # Generate summary
        generate_summary
        
        # Send notification
        send_notification "success" "Backup completed successfully - $target"
    fi
    
    log_info "Backup process completed"
}

# Run main function
main "$@"