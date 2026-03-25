#!/bin/bash
# backup.sh - Unified backup script for homelab-stack
# Supports: all, media, dry-run, restore, list, verify
#
# Usage:
#   ./backup.sh --target <stack|all> [options]
#
# Options:
#   --target all           Backup all stack volumes
#   --target media         Backup media stack only
#   --target <stack>       Backup specific stack
#   --dry-run              Show what would be backed up
#   --restore <backup_id>  Restore from backup
#   --list                 List all backups
#   --verify               Verify backup integrity
#
# Environment (.env):
#   BACKUP_TARGET=local|s3|b2|sftp|r2
#   BACKUP_DIR=./backups
#   NTFY_HOST=ntfy

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -E '^[A-Z]' "$ENV_FILE" | xargs)
fi

# Default configuration
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/../backups}"
NTFY_HOST="${NTFY_HOST:-ntfy}"
NTFY_PORT="${NTFY_PORT:-80}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Send notification via ntfy
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-3}"

    if [ -n "${NTFY_HOST}" ]; then
        curl -s -o /dev/null \
            --retry 2 \
            -H "Title: ${title}" \
            -H "Priority: ${priority}" \
            -H "Tags: backup" \
            -d "${message}" \
            "http://${NTFY_HOST}:${NTFY_PORT}/homelab-backups"
    fi
}

# Show usage
usage() {
    cat << EOF
${GREEN}backup.sh${NC} - Homelab-stack unified backup script

${GREEN}Usage:${NC}
    $0 --target <stack|all> [options]

${GREEN}Options:${NC}
    --target <stack>    Backup target: all, media, base, databases, productivity, or specific stack
    --dry-run           Show what would be backed up without executing
    --restore <id>      Restore from specified backup
    --list              List all available backups
    --verify            Verify backup integrity
    -h, --help          Show this help message

${GREEN}Examples:${NC}
    $0 --target all              Backup everything
    $0 --target media --dry-run Show media backup plan
    $0 --restore backup_20240101_020000
    $0 --list

${GREEN}Environment:${NC}
    BACKUP_TARGET=local|s3|b2|sftp|r2
    BACKUP_DIR=./backups
    NTFY_HOST=ntfy

EOF
    exit 0
}

# Stack volumes mapping
declare -A STACK_VOLUMES
STACK_VOLUMES["base"]="portainer_data watchtower_data"
STACK_VOLUMES["media"]="jellyfin_config sonarr_config radarr_config prowlarr_config qbittorrent_data"
STACK_VOLUMES["databases"]="postgres_data redis_data mariadb_data"
STACK_VOLUMES["productivity"]="gitea_data outline_data vaultwarden_data"
STACK_VOLUMES["network"]="adguard_data wireguard_data"
STACK_VOLUMES["storage"]="nextcloud_data minio_data"
STACK_VOLUMES["monitoring"]="prometheus_data grafana_data loki_data"

# Docker volumes to backup (all stacks)
ALL_VOLUMES="portainer_data watchtower_data jellyfin_config sonarr_config radarr_config prowlarr_config qbittorrent_data postgres_data redis_data mariadb_data gitea_data outline_data vaultwarden_data adguard_data wireguard_data nextcloud_data minio_data prometheus_data grafana_data loki_data"

# Parse arguments
TARGET="all"
DRY_RUN=false
ACTION="backup"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --restore)
            ACTION="restore"
            RESTORE_ID="$2"
            shift 2
            ;;
        --list)
            ACTION="list"
            shift
            ;;
        --verify)
            ACTION="verify"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get list of docker volumes
get_volume_list() {
    docker volume ls --format '{{.Name}}' | grep -E '\.(config|data)$' | sort
}

# Backup a single volume
backup_volume() {
    local volume_name="$1"
    local backup_file="$2"

    if docker volume inspect "$volume_name" >/dev/null 2>&1; then
        log "Backing up volume: ${volume_name}"
        if [ "$DRY_RUN" = true ]; then
            echo "  Would backup: ${volume_name} -> ${backup_file}"
        else
            docker run --rm \
                -v "${volume_name}:/src" \
                -v "$(dirname "${backup_file}"):/dest" \
                alpine \
                tar czf "/dest/$(basename "${backup_file}")" -C /src .
        fi
    else
        warn "Volume not found: ${volume_name}"
    fi
}

# Perform backup
do_backup() {
    log "Starting backup for target: ${TARGET}"
    log "Backup destination: ${BACKUP_TARGET}"

    # Create backup directory
    local backup_path="${BACKUP_DIR}/${TARGET}_${TIMESTAMP}"
    mkdir -p "${backup_path}"

    # Determine volumes to backup
    local volumes_to_backup=""

    if [ "$TARGET" = "all" ]; then
        volumes_to_backup="$ALL_VOLUMES"
    elif [ -n "${STACK_VOLUMES[$TARGET]}" ]; then
        volumes_to_backup="${STACK_VOLUMES[$TARGET]}"
    else
        # Check if it's a specific volume name
        volumes_to_backup="$TARGET"
    fi

    # Backup each volume
    local backed_up=0
    local failed=0

    for volume in $volumes_to_backup; do
        local backup_file="${backup_path}/${volume}.tar.gz"
        if backup_volume "$volume" "$backup_file"; then
            ((backed_up++)) || true
        else
            ((failed++)) || true
        fi
    done

    # Create manifest
    cat > "${backup_path}/manifest.txt" << EOF
Backup created: $(date)
Target: ${TARGET}
Hostname: $(hostname)
Backup destination: ${BACKUP_TARGET}
Volumes backed up: ${backed_up}
Volumes failed: ${failed}
EOF

    # Upload to remote if configured
    case "$BACKUP_TARGET" in
        s3|r2)
            log "Uploading to S3/R2..."
            upload_to_s3 "${backup_path}"
            ;;
        b2)
            log "Uploading to Backblaze B2..."
            upload_to_b2 "${backup_path}"
            ;;
        sftp)
            log "Uploading to SFTP..."
            upload_to_sftp "${backup_path}"
            ;;
        local|*)
            log "Backup saved locally: ${backup_path}"
            ;;
    esac

    # Cleanup old backups
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find "${BACKUP_DIR}" -maxdepth 1 -type d -name "${TARGET}_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

    # Send notification
    if [ "$DRY_RUN" = false ]; then
        if [ $failed -eq 0 ]; then
            notify "Backup Complete" "Successfully backed up ${backed_up} volumes to ${BACKUP_TARGET}" 3
        else
            notify "Backup Failed" "${failed} volumes failed to backup" 5
        fi
    fi

    log "Backup completed! Backed up: ${backed_up}, Failed: ${failed}"
}

# Upload to S3/R2
upload_to_s3() {
    local backup_path="$1"
    local bucket="${S3_BUCKET:-homelab-backups}"
    local endpoint="${S3_ENDPOINT:-}"
    local access_key="${AWS_ACCESS_KEY_ID:-}"
    local secret_key="${AWS_SECRET_ACCESS_KEY:-}"

    if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
        warn "S3 credentials not configured, skipping upload"
        return 1
    fi

    # Use mc (minio client) or aws cli
    if command -v mc &>/dev/null; then
        mc alias set homelab "${endpoint}" "${access_key}" "${secret_key}" 2>/dev/null || true
        mc cp -r "${backup_path}" "homelab/${bucket}/" 2>/dev/null && log "Uploaded to S3/R2" || warn "S3 upload failed"
    elif command -v aws &>/dev/null; then
        aws s3 cp --recursive "${backup_path}" "s3://${bucket}/" 2>/dev/null && log "Uploaded to S3" || warn "S3 upload failed"
    else
        warn "Neither mc nor aws cli available, skipping S3 upload"
    fi
}

# Upload to Backblaze B2
upload_to_b2() {
    local backup_path="$1"
    local bucket="${B2_BUCKET:-homelab-backups}"
    local key_id="${B2_KEY_ID:-}"
    local key="${B2_KEY:-}"

    if [ -z "$key_id" ] || [ -z "$key" ]; then
        warn "B2 credentials not configured, skipping upload"
        return 1
    fi

    if command -v b2 &>/dev/null; then
        B2_ACCOUNT_KEY="$key" b2 upload-file --noProgress "$bucket" "${backup_path}" "$(basename "${backup_path}")" 2>/dev/null && \
            log "Uploaded to B2" || warn "B2 upload failed"
    else
        warn "B2 cli not available, skipping B2 upload"
    fi
}

# Upload to SFTP
upload_to_sftp() {
    local backup_path="$1"
    local sftp_host="${SFTP_HOST:-}"
    local sftp_user="${SFTP_USER:-}"
    local sftp_pass="${SFTP_PASSWORD:-}"
    local sftp_path="${SFTP_PATH:-/backups}"

    if [ -z "$sftp_host" ] || [ -z "$sftp_user" ]; then
        warn "SFTP credentials not configured, skipping upload"
        return 1
    fi

    if command -v sshpass &>/dev/null; then
        sshpass -p "$sftp_pass" scp -r "${backup_path}" "${sftp_user}@${sftp_host}:${sftp_path}/" && \
            log "Uploaded to SFTP" || warn "SFTP upload failed"
    else
        warn "sshpass not available, skipping SFTP upload"
    fi
}

# List backups
do_list() {
    log "Available backups in ${BACKUP_DIR}:"
    echo ""
    if [ -d "${BACKUP_DIR}" ]; then
        find "${BACKUP_DIR}" -maxdepth 1 -type d -name "*_*" | sort -r | while read dir; do
            local name=$(basename "$dir")
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local date=$(stat -c %y "$dir" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            echo "  ${name} | ${size} | ${date}"
        done
    else
        echo "  No backups found"
    fi
}

# Verify backup
do_verify() {
    local backup_id="$1"
    local backup_path="${BACKUP_DIR}/${backup_id}"

    if [ ! -d "$backup_path" ]; then
        error "Backup not found: ${backup_id}"
        return 1
    fi

    log "Verifying backup: ${backup_id}"
    local failed=0

    for tarfile in "${backup_path}"/*.tar.gz; do
        if [ -f "$tarfile" ]; then
            local volname=$(basename "$tarfile" .tar.gz)
            if tar tzf "$tarfile" >/dev/null 2>&1; then
                log "  ${volname}: OK"
            else
                error "  ${volname}: CORRUPTED"
                ((failed++)) || true
            fi
        fi
    done

    if [ $failed -eq 0 ]; then
        log "Backup verification passed!"
    else
        error "Backup verification failed: ${failed} corrupted files"
    fi
}

# Restore from backup
do_restore() {
    local backup_id="$RESTORE_ID"
    local backup_path="${BACKUP_DIR}/${backup_id}"

    if [ ! -d "$backup_path" ]; then
        error "Backup not found: ${backup_id}"
        return 1
    fi

    warn "This will overwrite current data. Make sure you have a recent backup!"
    read -p "Are you sure you want to restore? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log "Restore cancelled"
        return 0
    fi

    log "Restoring from: ${backup_id}"

    for tarfile in "${backup_path}"/*.tar.gz; do
        if [ -f "$tarfile" ]; then
            local volname=$(basename "$tarfile" .tar.gz)
            log "Restoring volume: ${volname}"

            # Stop container using the volume if running
            docker ps --filter "volume=${volname}" -q | xargs -r docker stop >/dev/null 2>&1 || true

            # Restore volume
            docker run --rm \
                -v "${volname}:/dest" \
                -v "$(dirname "${tarfile}"):/src" \
                alpine \
                sh -c "rm -rf /dest/* && tar xzf '/src/$(basename "${tarfile}")' -C /dest"

            log "  ${volname}: Restored"
        fi
    done

    notify "Restore Complete" "Restored from backup ${backup_id}" 4
    log "Restore completed!"
}

# Main
case "$ACTION" in
    backup)
        do_backup
        ;;
    list)
        do_list
        ;;
    verify)
        do_verify "${RESTORE_ID:-$(ls -t "${BACKUP_DIR}" | head -1)}"
        ;;
    restore)
        do_restore
        ;;
esac
