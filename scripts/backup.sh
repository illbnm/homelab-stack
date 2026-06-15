#!/usr/bin/env bash

# =============================================================================
# backup.sh — HomeLab Stack Backup & Disaster Recovery Script
# 3-2-1 Backup Strategy: 3 copies, 2 media, 1 offsite
# =============================================================================

set -euo pipefail

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_ROOT="${REPO_ROOT}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    cat << EOF
Usage: backup.sh --target <stack|all> [options]

Options:
  --target all       Backup all Docker volumes
  --target <stack>   Backup volumes of a specific stack (e.g., monitoring, media)
  --dry-run          Show what would be done without actually doing it
  --retention <days> Number of days to keep backups (default: 7)
  -h, --help         Show this help message

Examples:
  backup.sh --target all
  backup.sh --target monitoring
  backup.sh --target all --retention 14
EOF
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse command line arguments
TARGET=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    log_error "--target is required"
    print_usage
fi

# =============================================================================
# Backup logic
# =============================================================================

# Function to backup a single Docker volume
backup_volume() {
    local volume_name="$1"
    local backup_dir="${BACKUP_ROOT}/volumes/${TARGET}/${TIMESTAMP}"
    local backup_file="${backup_dir}/${volume_name}.tar.gz"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would backup volume: ${volume_name} -> ${backup_file}"
        return
    fi

    mkdir -p "${backup_dir}"

    log_info "Backing up volume: ${volume_name}"
    if docker run --rm \
        -v "${volume_name}":/source:ro \
        -v "${backup_dir}":/backup \
        alpine tar czf "/backup/${volume_name}.tar.gz" -C /source .; then
        log_info "✓ Successfully backed up ${volume_name}"
        # Generate checksum
        sha256sum "${backup_file}" > "${backup_file}.sha256"
    else
        log_error "✗ Failed to backup ${volume_name}"
        return 1
    fi
}

# Function to get volumes associated with a specific stack or all
# Strategy: volumes named with stack prefix (e.g., monitoring_prometheus_data)
get_volumes_for_target() {
    local target="$1"
    local volumes

    if [[ "$target" == "all" ]]; then
        volumes=$(docker volume ls --format '{{.Name}}')
    else
        # Assume volumes follow pattern: stackname_*
        volumes=$(docker volume ls --filter name="^${target}_" --format '{{.Name}}')
        # Also include volumes from stack's docker-compose.yml
        # We can parse the compose file to get volume names, but simpler: just filter by name
    fi

    echo "$volumes"
}

# Function to clean old backups
cleanup_old_backups() {
    local target="$1"
    local backup_dir="${BACKUP_ROOT}/volumes/${target}"

    if [[ ! -d "$backup_dir" ]]; then
        return
    fi

    log_info "Cleaning backups older than ${RETENTION_DAYS} days for target: ${target}"
    find "${backup_dir}" -mindepth 1 -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
}

# Main backup process
main() {
    log_info "Starting backup for target: ${TARGET}"
    mkdir -p "${BACKUP_ROOT}/volumes/${TARGET}"

    local volumes
    volumes=$(get_volumes_for_target "$TARGET")

    if [[ -z "$volumes" ]]; then
        log_warn "No volumes found for target: ${TARGET}"
        exit 0
    fi

    local exit_code=0
    while IFS= read -r vol; do
        if [[ -n "$vol" ]]; then
            backup_volume "$vol" || exit_code=1
        fi
    done <<< "$volumes"

    cleanup_old_backups "$TARGET"

    if [[ $exit_code -eq 0 ]]; then
        log_info "Backup completed successfully for target: ${TARGET}"
    else
        log_error "Backup completed with errors for target: ${TARGET}"
    fi

    exit $exit_code
}

main
