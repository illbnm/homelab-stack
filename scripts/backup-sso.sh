#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Backup & Recovery Script
# Handles automated backups of Authentik data and configurations
# Usage: ./backup-sso.sh [backup|restore|list|status]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backup/authentik}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
BACKUP_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Load environment
load_env() {
    if [ -f "$ROOT_DIR/.env" ]; then
        set -a; source "$ROOT_DIR/.env"; set +a
    fi
    if [ -f "$SSO_DIR/.env" ]; then
        set -a; source "$SSO_DIR/.env"; set +a
    fi
}

# Check prerequisites
check_prerequisites() {
    local required_commands=("docker" "tar" "date")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            return 1
        fi
    done
    
    # Check backup directory
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "Backup directory '$BACKUP_DIR' does not exist, creating..."
        mkdir -p "$BACKUP_DIR" || {
            log_error "Failed to create backup directory"
            return 1
        }
    fi
    
    # Check write permissions
    if [ ! -w "$BACKUP_DIR" ]; then
        log_error "No write permissions for backup directory"
        return 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Check SSO stack status
check_sso_status() {
    cd "$SSO_DIR"
    
    if ! docker compose ps >/dev/null 2>&1; then
        log_error "SSO stack is not running"
        cd "$ROOT_DIR"
        return 1
    fi
    
    cd "$ROOT_DIR"
}

# Create backup
create_backup() {
    log_step "Creating SSO Backup"
    
    load_env
    check_prerequisites
    check_sso_status
    
    local backup_file="$BACKUP_DIR/authentik_backup_${BACKUP_TIMESTAMP}.tar.gz"
    local log_file="$BACKUP_DIR/backup_${BACKUP_TIMESTAMP}.log"
    
    log_info "Backup file: $backup_file"
    log_info "Backup log: $log_file"
    
    # Create temporary backup directory
    local temp_dir="/tmp/authentik_backup_${BACKUP_TIMESTAMP}"
    mkdir -p "$temp_dir"
    
    # Get environment variables (avoid including sensitive data)
    log_info "Capturing configuration..."
    
    cat > "$temp_dir/config.env" << EOF
# Authentik Configuration Backup
# Backup created: $(date)
# Domain: ${DOMAIN:-undefined}
# Authentik Domain: ${AUTHENTIK_DOMAIN:-undefined}
EOF
    
    # Capture docker compose configuration (without sensitive data)
    cp "$SSO_DIR/docker-compose.yml" "$temp_dir/"
    cp "$SSO_DIR/.env.example" "$temp_dir/"
    cp "$SSO_DIR/README.md" "$temp_dir/" 2>/dev/null || true
    
    # Backup Docker volumes
    log_info "Backing up Docker volumes..."
    
    local volumes=(
        "authentik_media"
        "authentik_templates" 
        "postgresql_data"
        "redis_data"
    )
    
    for volume in "${volumes[@]}"; do
        log_info "Backing up volume: $volume"
        
        # Create volume backup
        docker run --rm \
            -v "$volume":/data \
            -v "$temp_dir":/backup \
            alpine tar czf "/backup/${volume}.tar.gz" -C /data . 2>> "$log_file" || {
            log_error "Failed to backup volume: $volume"
            continue
        }
    done
    
    # Backup scripts
    log_info "Backing up scripts..."
    mkdir -p "$temp_dir/scripts"
    cp "$ROOT_DIR/scripts/setup-authentik-enhanced.sh" "$temp_dir/scripts/" 2>/dev/null || true
    cp "$ROOT_DIR/scripts/monitor-sso.sh" "$temp_dir/scripts/" 2>/dev/null || true
    cp "$ROOT_DIR/scripts/test-sso.sh" "$temp_dir/scripts/" 2>/dev/null || true
    
    # Create backup manifest
    cat > "$temp_dir/manifest.txt" << EOF
Authentik Backup Manifest
========================
Backup Date: $(date)
Backup Timestamp: $BACKUP_TIMESTAMP
Backup Size: $(du -sh "$temp_dir" | cut -f1)
Included:
  - Environment configuration (template)
  - Docker Compose files
  - Docker volumes:
    - authentik_media
    - authentik_templates
    - postgresql_data
    - redis_data
  - Scripts and documentation

To restore:
  1. Stop SSO services: docker compose down
  2. Restore volumes: docker run --rm -v <volume>:/data -v ./backup:/backup alpine tar xzf backup/<volume>.tar.gz -C /data
  3. Start services: docker compose up -d
EOF
    
    # Create final backup archive
    log_info "Creating final backup archive..."
    cd "$(dirname "$temp_dir")"
    tar czf "$backup_file" "$(basename "$temp_dir")" 2>> "$log_file"
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    # Set appropriate permissions
    chmod 600 "$backup_file"
    chmod 644 "$log_file"
    
    # Get backup size
    local backup_size
    backup_size=$(du -sh "$backup_file" | cut -f1)
    
    log_info "✓ Backup completed successfully"
    log_info "  Size: $backup_size"
    log_info "  File: $backup_file"
    
    # Clean old backups
    cleanup_old_backups
}

# Restore from backup
restore_backup() {
    local backup_file="${1:-}"
    
    log_step "Restoring SSO from Backup"
    
    if [ -z "$backup_file" ]; then
        log_error "No backup file specified"
        log_info "Available backups:"
        list_backups
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    load_env
    
    log_info "Backup file: $backup_file"
    
    # Check backup file integrity
    if ! tar -tzf "$backup_file" >/dev/null; then
        log_error "Backup file is corrupted"
        return 1
    fi
    
    # Create temporary extraction directory
    local temp_dir="/tmp/authentik_restore_$$"
    mkdir -p "$temp_dir"
    
    # Extract backup
    log_info "Extracting backup..."
    tar xzf "$backup_file" -C "$temp_dir" 2>/dev/null || {
        log_error "Failed to extract backup"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Check manifest
    if [ ! -f "$temp_dir/manifest.txt" ]; then
        log_error "Backup manifest not found - this backup may be incomplete"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Backup manifest:"
    cat "$temp_dir/manifest.txt"
    
    # Stop SSO services
    log_info "Stopping SSO services..."
    cd "$SSO_DIR"
    docker compose down
    
    # Backup current data before restore
    log_info "Creating pre-restore backup..."
    local pre_backup_file="$BACKUP_DIR/pre_restore_backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    docker compose down
    docker run --rm \
        -v authentik_media:/data \
        -v authentik_templates:/data \
        -v postgresql_data:/data \
        -v redis_data:/data \
        -v "$(dirname "$pre_backup_file")":/backup \
        alpine tar czf "/backup/$(basename "$pre_backup_file")" -C /data . 2>/dev/null || true
    
    # Restore volumes
    log_info "Restoring volumes..."
    
    local volume_mapping=(
        "authentik_media:media"
        "authentik_templates:templates"
        "postgresql_data:postgresql/data"
        "redis_data:redis/data"
    )
    
    for volume_mapping_item in "${volume_mapping[@]}"; do
        local volume="${volume_mapping_item%%:*}"
        local backup_subdir="${volume_mapping_item##*:}"
        
        if [ -f "$temp_dir/${volume}.tar.gz" ]; then
            log_info "Restoring volume: $volume"
            
            docker run --rm \
                -v "$volume":/data \
                -v "$temp_dir":/backup \
                alpine tar xzf "/backup/${volume}.tar.gz" -C /data . || {
                log_error "Failed to restore volume: $volume"
                continue
            }
        else
            log_warn "⚠ Volume backup not found: $volume"
        fi
    done
    
    # Start SSO services
    log_info "Starting SSO services..."
    docker compose up -d
    
    # Verify restore
    log_info "Verifying restore..."
    sleep 30  # Wait for services to start
    
    local authentik_url="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN:-localhost}}"
    if curl -sf "$authentik_url/-/health/ready/" -o /dev/null; then
        log_info "✓ Authentik is running after restore"
    else
        log_warn "⚠ Authentik may not be fully operational after restore"
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    log_info "✓ Restore completed successfully"
    log_info "  Pre-restore backup saved to: $pre_backup_file"
}

# List available backups
list_backups() {
    log_step "Available Backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "No backup directory found"
        return
    fi
    
    local backups=("$BACKUP_DIR"/authentik_backup_*.tar.gz)
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_info "No backups found"
        return
    fi
    
    printf "%-20s %15s %s\n" "Date" "Size" "File"
    printf "%-20s %15s %s\n" "----" "----" "----"
    
    for backup_file in "${backups[@]}"; do
        local filename=$(basename "$backup_file")
        local filedate=$(echo "$filename" | sed 's/authentik_backup_//' | sed 's/\.tar.gz//')
        local filesize=$(du -sh "$backup_file" | cut -f1)
        
        printf "%-20s %15s %s\n" "$filedate" "$filesize" "$filename"
    done
}

# Cleanup old backups
cleanup_old_backups() {
    log_step "Cleaning old backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        return
    fi
    
    # Find and remove backups older than retention period
    find "$BACKUP_DIR" -name "authentik_backup_*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;
    
    log_info "✓ Cleanup completed"
}

# Show backup status
show_status() {
    log_step "Backup Status"
    
    load_env
    check_prerequisites
    
    # Backup directory info
    if [ -d "$BACKUP_DIR" ]; then
        local total_backups
        total_backups=$(find "$BACKUP_DIR" -name "authentik_backup_*.tar.gz" | wc -l)
        local total_size
        total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
        
        log_info "Backup directory: $BACKUP_DIR"
        log_info "Total backups: $total_backups"
        log_info "Total size: $total_size"
        log_info "Retention: $RETENTION_DAYS days"
    else
        log_warn "No backup directory found"
    fi
    
    # SSO stack status
    if check_sso_status >/dev/null 2>&1; then
        log_info "SSO stack: Running"
    else
        log_warn "SSO stack: Not running"
    fi
}

# Main execution
case "${1:-status}" in
    "backup")
        create_backup
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "list")
        list_backups
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Usage: $0 [backup|restore|list|status]"
        echo "  backup    - Create a new backup"
        echo "  restore   - Restore from backup (specify backup file)"
        echo "  list      - List available backups"
        echo "  status    - Show backup status"
        exit 1
        ;;
esac