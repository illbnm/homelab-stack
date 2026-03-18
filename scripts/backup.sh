#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Backup & Disaster Recovery
# Full 3-2-1 backup solution: 3 copies, 2 media types, 1 offsite
#
# Usage:
#   backup.sh --target <stack|all> [options]
#   backup.sh --list
#   backup.sh --restore <backup_id>
#   backup.sh --verify [backup_id]
#
# Supports: local, s3 (MinIO), b2 (Backblaze), sftp, r2 (Cloudflare)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_DIR/.env"
BACKUP_ENV_FILE="$BASE_DIR/stacks/backup/.env"

# Load environment
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
[[ -f "$BACKUP_ENV_FILE" ]] && source "$BACKUP_ENV_FILE"

# --- Configuration -----------------------------------------------------------
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"         # local|s3|b2|sftp|r2
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
RETENTION_COUNT="${BACKUP_RETENTION_COUNT:-30}"
NOTIFY_URL="${NTFY_URL:-}"
NOTIFY_TOPIC="${NTFY_BACKUP_TOPIC:-homelab-backup}"

# S3 / MinIO
S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-}"
S3_BUCKET="${BACKUP_S3_BUCKET:-homelab-backups}"
S3_ACCESS_KEY="${BACKUP_S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${BACKUP_S3_SECRET_KEY:-}"

# Backblaze B2
B2_BUCKET="${BACKUP_B2_BUCKET:-}"
B2_KEY_ID="${BACKUP_B2_KEY_ID:-}"
B2_APPLICATION_KEY="${BACKUP_B2_APPLICATION_KEY:-}"

# SFTP
SFTP_HOST="${BACKUP_SFTP_HOST:-}"
SFTP_USER="${BACKUP_SFTP_USER:-}"
SFTP_PATH="${BACKUP_SFTP_PATH:-/backups}"
SFTP_KEY="${BACKUP_SFTP_KEY:-$HOME/.ssh/id_rsa}"

# Cloudflare R2
R2_ENDPOINT="${BACKUP_R2_ENDPOINT:-}"
R2_BUCKET="${BACKUP_R2_BUCKET:-homelab-backups}"
R2_ACCESS_KEY="${BACKUP_R2_ACCESS_KEY:-}"
R2_SECRET_KEY="${BACKUP_R2_SECRET_KEY:-}"

# Encryption
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
ENCRYPT_BACKUPS="${BACKUP_ENCRYPT:-false}"

# --- Colors -------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# --- Logging ------------------------------------------------------------------
log_info()    { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error()   { echo -e "${RED}[backup]${NC} $*" >&2; }
log_header()  { echo -e "\n${BOLD}${BLUE}═══ $* ═══${NC}"; }
log_step()    { echo -e "${CYAN}  ▸${NC} $*"; }

# --- Notification -------------------------------------------------------------
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-}"

    # Try scripts/notify.sh first (unified notification interface)
    if [[ -x "$SCRIPT_DIR/notify.sh" ]]; then
        "$SCRIPT_DIR/notify.sh" "$NOTIFY_TOPIC" "$title" "$message" "$priority"
        return
    fi

    # Direct ntfy
    if [[ -n "$NOTIFY_URL" ]]; then
        curl -sf \
            -H "Title: $title" \
            -H "Priority: $priority" \
            ${tags:+-H "Tags: $tags"} \
            -d "$message" \
            "${NOTIFY_URL}/${NOTIFY_TOPIC}" >/dev/null 2>&1 || true
    fi
}

# --- Stack mapping ------------------------------------------------------------
declare -A STACK_DIRS=(
    [base]="stacks/base"
    [network]="stacks/network"
    [storage]="stacks/storage"
    [databases]="stacks/databases"
    [media]="stacks/media"
    [monitoring]="stacks/monitoring"
    [productivity]="stacks/productivity"
    [ai]="stacks/ai"
    [sso]="stacks/sso"
    [home-automation]="stacks/home-automation"
    [notifications]="stacks/notifications"
)

declare -A STACK_VOLUMES=(
    [base]="portainer-data traefik-logs"
    [network]="adguard-data adguard-conf npm-data npm-letsencrypt"
    [storage]="nextcloud-html nextcloud-db minio-data filebrowser-data"
    [databases]="postgres-data redis-data mariadb-data"
    [media]="jellyfin-config jellyfin-cache prowlarr-config sonarr-config radarr-config qbittorrent-config"
    [monitoring]="prometheus-data grafana-data loki-data alertmanager-data"
    [productivity]="gitea-data vaultwarden-data outline-data bookstack-data"
    [ai]="ollama-data open-webui-data"
    [sso]="authentik-postgres authentik-redis authentik-media authentik-templates"
    [home-automation]="homeassistant-config nodered-data mosquitto-data mosquitto-log zigbee2mqtt-data"
    [notifications]="ntfy-data ntfy-cache apprise-config"
)

declare -A STACK_DATABASES=(
    [databases]="postgres:homelab-postgres:postgres redis:homelab-redis mariadb:homelab-mariadb:root"
    [sso]="postgres:authentik-postgres:authentik redis:authentik-redis"
    [productivity]="postgres:gitea-postgres:gitea"
    [storage]="postgres:nextcloud-postgres:nextcloud"
)

# --- Helper functions ---------------------------------------------------------

get_stack_volumes() {
    local stack="$1"
    echo "${STACK_VOLUMES[$stack]:-}"
}

volume_exists() {
    docker volume inspect "$1" >/dev/null 2>&1
}

backup_id_from_path() {
    basename "$1"
}

create_metadata() {
    local backup_path="$1"
    local target_stack="$2"
    local start_time="$3"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local total_size
    total_size=$(du -sb "$backup_path" 2>/dev/null | cut -f1 || echo "0")

    cat > "$backup_path/backup.meta" <<EOF
{
  "id": "$(backup_id_from_path "$backup_path")",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "target": "$target_stack",
  "duration_seconds": $duration,
  "total_bytes": ${total_size:-0},
  "hostname": "$(hostname)",
  "docker_version": "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')",
  "backup_target": "$BACKUP_TARGET",
  "encrypted": $ENCRYPT_BACKUPS,
  "retention_days": $RETENTION_DAYS
}
EOF
    log_step "Metadata saved"
}

generate_checksums() {
    local backup_path="$1"
    log_step "Generating checksums..."
    cd "$backup_path"
    find . -type f ! -name 'checksums.sha256' ! -name 'backup.meta' \
        -exec sha256sum {} + > checksums.sha256 2>/dev/null || true
    cd - >/dev/null
}

encrypt_backup() {
    local backup_path="$1"
    if [[ "$ENCRYPT_BACKUPS" != "true" ]] || [[ -z "$ENCRYPTION_KEY" ]]; then
        return 0
    fi
    log_step "Encrypting backup..."
    local archive="${backup_path}.tar.gz"
    tar czf "$archive" -C "$(dirname "$backup_path")" "$(basename "$backup_path")"
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$archive" -out "${archive}.enc" \
        -pass "pass:${ENCRYPTION_KEY}"
    rm -f "$archive"
    rm -rf "$backup_path"
    log_step "Encrypted: ${archive}.enc"
}

decrypt_backup() {
    local enc_file="$1"
    local output_dir="$2"
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        log_error "BACKUP_ENCRYPTION_KEY required for decryption"
        return 1
    fi
    local archive="${enc_file%.enc}"
    openssl enc -d -aes-256-cbc -pbkdf2 \
        -in "$enc_file" -out "$archive" \
        -pass "pass:${ENCRYPTION_KEY}"
    tar xzf "$archive" -C "$output_dir"
    rm -f "$archive"
}

# --- Remote upload/download ---------------------------------------------------

remote_upload() {
    local local_path="$1"
    local remote_name="$2"

    case "$BACKUP_TARGET" in
        local) return 0 ;;
        s3)
            log_step "Uploading to S3: $S3_BUCKET/$remote_name"
            if command -v aws &>/dev/null; then
                aws s3 sync "$local_path" "s3://$S3_BUCKET/$remote_name" \
                    --endpoint-url "$S3_ENDPOINT" 2>/dev/null
            elif command -v mc &>/dev/null; then
                mc alias set backup "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" 2>/dev/null
                mc mirror --overwrite "$local_path" "backup/$S3_BUCKET/$remote_name" 2>/dev/null
            else
                log_error "aws CLI or mc (MinIO Client) required for S3 uploads"
                return 1
            fi
            ;;
        b2)
            log_step "Uploading to Backblaze B2: $B2_BUCKET/$remote_name"
            if command -v rclone &>/dev/null; then
                RCLONE_CONFIG_B2_TYPE=b2 \
                RCLONE_CONFIG_B2_ACCOUNT="$B2_KEY_ID" \
                RCLONE_CONFIG_B2_KEY="$B2_APPLICATION_KEY" \
                rclone sync "$local_path" "b2:$B2_BUCKET/$remote_name" 2>/dev/null
            elif command -v b2 &>/dev/null; then
                b2 authorize-account "$B2_KEY_ID" "$B2_APPLICATION_KEY" 2>/dev/null
                b2 sync "$local_path" "b2://$B2_BUCKET/$remote_name" 2>/dev/null
            else
                log_error "rclone or b2 CLI required for B2 uploads"
                return 1
            fi
            ;;
        sftp)
            log_step "Uploading to SFTP: $SFTP_HOST:$SFTP_PATH/$remote_name"
            rsync -avz -e "ssh -i $SFTP_KEY -o StrictHostKeyChecking=no" \
                "$local_path/" \
                "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/${remote_name}/" 2>/dev/null
            ;;
        r2)
            log_step "Uploading to Cloudflare R2: $R2_BUCKET/$remote_name"
            AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
            AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
            aws s3 sync "$local_path" "s3://$R2_BUCKET/$remote_name" \
                --endpoint-url "$R2_ENDPOINT" 2>/dev/null
            ;;
        *) log_error "Unknown backup target: $BACKUP_TARGET"; return 1 ;;
    esac
}

remote_download() {
    local remote_name="$1"
    local local_path="$2"
    mkdir -p "$local_path"

    case "$BACKUP_TARGET" in
        local)
            if [[ -d "$BACKUP_DIR/$remote_name" ]]; then
                cp -a "$BACKUP_DIR/$remote_name/." "$local_path/"
            else
                log_error "Local backup not found: $BACKUP_DIR/$remote_name"
                return 1
            fi
            ;;
        s3)
            aws s3 sync "s3://$S3_BUCKET/$remote_name" "$local_path" \
                --endpoint-url "$S3_ENDPOINT" 2>/dev/null
            ;;
        b2)
            RCLONE_CONFIG_B2_TYPE=b2 \
            RCLONE_CONFIG_B2_ACCOUNT="$B2_KEY_ID" \
            RCLONE_CONFIG_B2_KEY="$B2_APPLICATION_KEY" \
            rclone sync "b2:$B2_BUCKET/$remote_name" "$local_path" 2>/dev/null
            ;;
        sftp)
            rsync -avz -e "ssh -i $SFTP_KEY -o StrictHostKeyChecking=no" \
                "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/${remote_name}/" \
                "$local_path/" 2>/dev/null
            ;;
        r2)
            AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
            AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
            aws s3 sync "s3://$R2_BUCKET/$remote_name" "$local_path" \
                --endpoint-url "$R2_ENDPOINT" 2>/dev/null
            ;;
    esac
}

# --- Backup functions ---------------------------------------------------------

backup_volume() {
    local vol="$1"
    local backup_path="$2"

    if ! volume_exists "$vol"; then
        log_warn "    Volume $vol not found, skipping"
        return 0
    fi
    log_step "  Volume: $vol"
    docker run --rm \
        -v "${vol}:/source:ro" \
        -v "$backup_path:/backup" \
        alpine:3.19 \
        tar czf "/backup/vol_${vol}.tar.gz" -C /source . 2>/dev/null || {
            log_warn "    Failed to backup volume: $vol"
            return 1
        }
}

backup_database() {
    local db_spec="$1"
    local backup_path="$2"
    IFS=':' read -r db_type container db_user <<< "$db_spec"

    case "$db_type" in
        postgres)
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                log_step "  PostgreSQL: $container"
                local pg_pass
                pg_pass=$(docker inspect "$container" \
                    --format '{{range .Config.Env}}{{println .}}{{end}}' \
                    | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
                docker exec "$container" \
                    sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U '${db_user:-postgres}'" \
                    2>/dev/null | gzip > "$backup_path/db_${container}.sql.gz" || {
                        log_warn "    PostgreSQL dump failed: $container"
                        return 1
                    }
            fi
            ;;
        redis)
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                log_step "  Redis: $container"
                docker exec "$container" redis-cli BGSAVE >/dev/null 2>&1
                sleep 2
                docker cp "${container}:/data/dump.rdb" \
                    "$backup_path/db_${container}.rdb" 2>/dev/null || {
                        log_warn "    Redis backup failed: $container"
                        return 1
                    }
            fi
            ;;
        mariadb)
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                log_step "  MariaDB: $container"
                local mysql_pass
                mysql_pass=$(docker inspect "$container" \
                    --format '{{range .Config.Env}}{{println .}}{{end}}' \
                    | grep -E 'MYSQL_ROOT_PASSWORD|MARIADB_ROOT_PASSWORD' \
                    | cut -d= -f2 | head -1)
                docker exec "$container" \
                    sh -c "mariadb-dump -u '${db_user:-root}' -p'$mysql_pass' --all-databases" \
                    2>/dev/null | gzip > "$backup_path/db_${container}.sql.gz" || {
                        log_warn "    MariaDB dump failed: $container"
                        return 1
                    }
            fi
            ;;
    esac
}

backup_configs() {
    local backup_path="$1"
    log_step "Backing up configuration files..."
    tar czf "$backup_path/configs.tar.gz" \
        -C "$BASE_DIR" \
        --exclude='stacks/*/data' \
        --exclude='*.log' \
        config/ stacks/ scripts/ .env 2>/dev/null || {
            log_warn "  Config backup partial — some files may be missing"
        }
}

backup_stack() {
    local stack="$1"
    local backup_path="$2"
    local failed=0

    log_header "Backing up: $stack"

    # Backup volumes
    local volumes
    volumes=$(get_stack_volumes "$stack")
    if [[ -n "$volumes" ]]; then
        local vol_dir="$backup_path/volumes"
        mkdir -p "$vol_dir"
        for vol in $volumes; do
            backup_volume "$vol" "$vol_dir" || ((failed++))
        done
    fi

    # Backup databases
    local db_specs="${STACK_DATABASES[$stack]:-}"
    if [[ -n "$db_specs" ]]; then
        local db_dir="$backup_path/databases"
        mkdir -p "$db_dir"
        for spec in $db_specs; do
            backup_database "$spec" "$db_dir" || ((failed++))
        done
    fi

    return $failed
}

# --- Main operations ----------------------------------------------------------

do_backup() {
    local target="$1"
    local dry_run="${2:-false}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_id="backup_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_id"
    local start_time
    start_time=$(date +%s)
    local total_failed=0

    # Determine stacks to backup
    local stacks=()
    if [[ "$target" == "all" ]]; then
        stacks=("${!STACK_DIRS[@]}")
    else
        if [[ -z "${STACK_DIRS[$target]+x}" ]]; then
            log_error "Unknown stack: $target"
            log_info "Available stacks: ${!STACK_DIRS[*]}"
            return 1
        fi
        stacks=("$target")
    fi
    IFS=$'\n' read -r -d '' -a stacks < <(printf '%s\n' "${stacks[@]}" | sort && printf '\0') || true

    if [[ "$dry_run" == "true" ]]; then
        log_header "DRY RUN — showing what would be backed up"
        echo ""
        for stack in "${stacks[@]}"; do
            echo -e "${BOLD}Stack: $stack${NC}"
            local volumes
            volumes=$(get_stack_volumes "$stack")
            if [[ -n "$volumes" ]]; then
                echo "  Volumes:"
                for vol in $volumes; do
                    if volume_exists "$vol"; then
                        echo "    ✓ $vol"
                    else
                        echo "    ✗ $vol (not found)"
                    fi
                done
            fi
            local db_specs="${STACK_DATABASES[$stack]:-}"
            if [[ -n "$db_specs" ]]; then
                echo "  Databases:"
                for spec in $db_specs; do
                    IFS=':' read -r db_type container _ <<< "$spec"
                    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
                        echo "    ✓ $db_type ($container)"
                    else
                        echo "    ✗ $db_type ($container — not running)"
                    fi
                done
            fi
            echo ""
        done
        echo -e "${BOLD}Target:${NC} $BACKUP_TARGET"
        [[ "$ENCRYPT_BACKUPS" == "true" ]] && echo -e "${BOLD}Encryption:${NC} enabled"
        return 0
    fi

    mkdir -p "$backup_path"
    log_header "HomeLab Backup — $timestamp"
    log_info "Target: $BACKUP_TARGET | Stacks: ${stacks[*]}"
    log_info "Backup ID: $backup_id"

    backup_configs "$backup_path"
    for stack in "${stacks[@]}"; do
        backup_stack "$stack" "$backup_path" || ((total_failed += $?))
    done

    generate_checksums "$backup_path"
    create_metadata "$backup_path" "$target" "$start_time"
    encrypt_backup "$backup_path"

    if [[ "$BACKUP_TARGET" != "local" ]]; then
        remote_upload "$backup_path" "$backup_id" || {
            log_error "Remote upload failed!"
            notify "❌ Backup Failed" "Remote upload to $BACKUP_TARGET failed for $backup_id" "urgent" "warning"
            return 1
        }
    fi

    cleanup_old_backups

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local total_size
    total_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1 || echo "N/A")

    log_header "Backup Complete"
    log_info "ID:       $backup_id"
    log_info "Size:     $total_size"
    log_info "Duration: ${duration}s"
    log_info "Target:   $BACKUP_TARGET"
    log_info "Stacks:   ${stacks[*]}"
    [[ $total_failed -gt 0 ]] && log_warn "Warnings: $total_failed items had issues"

    if [[ $total_failed -eq 0 ]]; then
        notify "✅ Backup Complete" \
            "ID: $backup_id | Size: $total_size | Duration: ${duration}s | Stacks: ${stacks[*]}" \
            "default" "white_check_mark"
    else
        notify "⚠️ Backup Partial" \
            "ID: $backup_id | Size: $total_size | Warnings: $total_failed | Stacks: ${stacks[*]}" \
            "high" "warning"
    fi
    echo "$backup_id"
}

do_restore() {
    local backup_id="$1"
    log_header "Restore from: $backup_id"

    local restore_path="$BACKUP_DIR/$backup_id"
    if [[ ! -d "$restore_path" ]]; then
        if [[ -f "${restore_path}.tar.gz.enc" ]]; then
            log_step "Decrypting backup..."
            mkdir -p "$restore_path"
            decrypt_backup "${restore_path}.tar.gz.enc" "$BACKUP_DIR"
        elif [[ "$BACKUP_TARGET" != "local" ]]; then
            log_step "Downloading from $BACKUP_TARGET..."
            remote_download "$backup_id" "$restore_path"
        else
            log_error "Backup not found: $backup_id"
            log_info "Use 'backup.sh --list' to see available backups"
            return 1
        fi
    fi

    # Verify checksums
    if [[ -f "$restore_path/checksums.sha256" ]]; then
        log_step "Verifying checksums..."
        cd "$restore_path"
        if ! sha256sum -c checksums.sha256 >/dev/null 2>&1; then
            log_error "Checksum verification failed! Backup may be corrupted."
            cd - >/dev/null
            return 1
        fi
        cd - >/dev/null
        log_step "Checksums verified ✓"
    fi

    echo ""
    log_info "The following will be restored:"
    if [[ -d "$restore_path/volumes" ]]; then
        echo "  Volumes:"
        find "$restore_path/volumes" -name 'vol_*.tar.gz' -exec basename {} \; \
            | sed 's/^vol_//;s/\.tar\.gz$//' | while read -r vol; do
            echo "    ▸ $vol"
        done
    fi
    if [[ -d "$restore_path/databases" ]]; then
        echo "  Databases:"
        find "$restore_path/databases" -type f | while read -r f; do
            echo "    ▸ $(basename "$f")"
        done
    fi
    [[ -f "$restore_path/configs.tar.gz" ]] && echo "  Configs: configs.tar.gz"

    echo ""
    echo -e "${YELLOW}⚠️  WARNING: Restoring will OVERWRITE existing data!${NC}"
    echo -n "Continue? [y/N] "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Restore cancelled"
        return 0
    fi

    # Restore configs
    if [[ -f "$restore_path/configs.tar.gz" ]]; then
        log_step "Restoring configs..."
        tar xzf "$restore_path/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || true
    fi

    # Restore volumes
    if [[ -d "$restore_path/volumes" ]]; then
        for archive in "$restore_path/volumes"/vol_*.tar.gz; do
            [[ ! -f "$archive" ]] && continue
            local vol_name
            vol_name=$(basename "$archive" | sed 's/^vol_//;s/\.tar\.gz$//')
            log_step "Restoring volume: $vol_name"
            docker volume create "$vol_name" >/dev/null 2>&1 || true
            docker run --rm \
                -v "${vol_name}:/target" \
                -v "$(dirname "$archive"):/backup:ro" \
                alpine:3.19 \
                sh -c "rm -rf /target/* && tar xzf /backup/$(basename "$archive") -C /target" || {
                    log_warn "  Failed to restore volume: $vol_name"
                }
        done
    fi

    # Restore databases
    if [[ -d "$restore_path/databases" ]]; then
        for db_file in "$restore_path/databases"/db_*; do
            [[ ! -f "$db_file" ]] && continue
            local filename
            filename=$(basename "$db_file")
            log_step "Restoring database: $filename"

            if [[ "$filename" == *.sql.gz ]]; then
                local container
                container=$(echo "$filename" | sed 's/^db_//;s/\.sql\.gz$//')
                if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                    if [[ "$container" == *postgres* ]]; then
                        local pg_pass
                        pg_pass=$(docker inspect "$container" \
                            --format '{{range .Config.Env}}{{println .}}{{end}}' \
                            | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
                        zcat "$db_file" | docker exec -i "$container" \
                            sh -c "PGPASSWORD='$pg_pass' psql -U postgres" 2>/dev/null || \
                            log_warn "  PostgreSQL restore failed: $container"
                    elif [[ "$container" == *mariadb* ]] || [[ "$container" == *mysql* ]]; then
                        local mysql_pass
                        mysql_pass=$(docker inspect "$container" \
                            --format '{{range .Config.Env}}{{println .}}{{end}}' \
                            | grep -E 'MYSQL_ROOT_PASSWORD|MARIADB_ROOT_PASSWORD' \
                            | cut -d= -f2 | head -1)
                        zcat "$db_file" | docker exec -i "$container" \
                            sh -c "mysql -u root -p'$mysql_pass'" 2>/dev/null || \
                            log_warn "  MariaDB restore failed: $container"
                    fi
                else
                    log_warn "  Container not running: $container — skipping"
                fi
            elif [[ "$filename" == *.rdb ]]; then
                local container
                container=$(echo "$filename" | sed 's/^db_//;s/\.rdb$//')
                if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                    docker cp "$db_file" "${container}:/data/dump.rdb" 2>/dev/null
                    docker restart "$container" 2>/dev/null || true
                else
                    log_warn "  Container not running: $container — skipping Redis restore"
                fi
            fi
        done
    fi

    log_header "Restore Complete"
    log_info "Restored from: $backup_id"
    log_info "Restart services: docker compose up -d"
    notify "🔄 Restore Complete" "Restored from backup: $backup_id" "default" "recycle"
}

do_list() {
    log_header "Available Backups"
    local found=false

    if [[ -d "$BACKUP_DIR" ]]; then
        for dir in "$BACKUP_DIR"/backup_*; do
            [[ ! -d "$dir" && ! -f "$dir" ]] && continue
            found=true

            # Encrypted backup
            if [[ "$dir" == *.tar.gz.enc ]]; then
                local id
                id=$(basename "$dir" | sed 's/\.tar\.gz\.enc$//')
                local size
                size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                echo -e "  ${GREEN}$id${NC} ($size) [encrypted]"
                continue
            fi

            [[ ! -d "$dir" ]] && continue
            local id
            id=$(basename "$dir")
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local meta=""
            if [[ -f "$dir/backup.meta" ]]; then
                local target
                target=$(grep -o '"target": "[^"]*"' "$dir/backup.meta" | cut -d'"' -f4)
                local ts
                ts=$(grep -o '"timestamp": "[^"]*"' "$dir/backup.meta" | cut -d'"' -f4)
                meta=" | target=$target | $ts"
            fi
            echo -e "  ${GREEN}$id${NC} ($size)${meta}"
        done
    fi

    if [[ "$found" == "false" ]]; then
        log_info "No backups found in $BACKUP_DIR"
    fi
    echo ""
    log_info "Backup dir: $BACKUP_DIR"
    log_info "Target: $BACKUP_TARGET"
}

do_verify() {
    local backup_id="${1:-}"
    if [[ -z "$backup_id" ]]; then
        backup_id=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | sort -r | head -1 | xargs basename 2>/dev/null || true)
        if [[ -z "$backup_id" ]]; then
            log_error "No backups found to verify"
            return 1
        fi
    fi

    local backup_path="$BACKUP_DIR/$backup_id"
    log_header "Verifying: $backup_id"
    local errors=0

    if [[ ! -d "$backup_path" ]]; then
        if [[ -f "${backup_path}.tar.gz.enc" ]]; then
            log_info "Backup is encrypted — decrypt first to verify contents"
            return 0
        fi
        log_error "Backup not found: $backup_path"
        return 1
    fi

    # Metadata
    if [[ -f "$backup_path/backup.meta" ]]; then
        log_step "Metadata: ✓"
    else
        log_warn "Metadata: ✗ (missing)"; ((errors++))
    fi

    # Checksums
    if [[ -f "$backup_path/checksums.sha256" ]]; then
        cd "$backup_path"
        if sha256sum -c checksums.sha256 >/dev/null 2>&1; then
            local count
            count=$(wc -l < checksums.sha256)
            log_step "Checksums: ✓ ($count files verified)"
        else
            log_error "Checksums: ✗ (verification failed)"; ((errors++))
        fi
        cd - >/dev/null
    else
        log_warn "Checksums: ✗ (missing)"; ((errors++))
    fi

    # Archive integrity
    local archives=0
    local corrupt=0
    while IFS= read -r -d '' f; do
        ((archives++))
        if ! gzip -t "$f" 2>/dev/null; then
            log_error "  Corrupt: $(basename "$f")"; ((corrupt++))
        fi
    done < <(find "$backup_path" -name '*.tar.gz' -print0 -o -name '*.sql.gz' -print0 2>/dev/null)

    if [[ $archives -gt 0 ]]; then
        log_step "Archives: $((archives - corrupt))/$archives OK"
        [[ $corrupt -gt 0 ]] && ((errors += corrupt))
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_info "Verification: PASSED ✓"
    else
        log_error "Verification: FAILED ($errors errors)"
        return 1
    fi
}

cleanup_old_backups() {
    log_step "Cleaning up old backups..."
    find "$BACKUP_DIR" -maxdepth 1 -type d -name 'backup_*' -mtime +"$RETENTION_DAYS" \
        -exec rm -rf {} + 2>/dev/null || true
    find "$BACKUP_DIR" -maxdepth 1 -name 'backup_*.tar.gz.enc' -mtime +"$RETENTION_DAYS" \
        -delete 2>/dev/null || true

    local count
    count=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | wc -l)
    if [[ $count -gt $RETENTION_COUNT ]]; then
        local to_delete=$((count - RETENTION_COUNT))
        ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | sort | head -n "$to_delete" | while read -r d; do
            log_step "  Removing old: $(basename "$d")"
            rm -rf "$d"
        done
    fi
}

# --- Usage --------------------------------------------------------------------
usage() {
    cat <<'EOF'
HomeLab Backup & Disaster Recovery

Usage:
  backup.sh --target <stack|all> [options]
  backup.sh --list
  backup.sh --restore <backup_id>
  backup.sh --verify [backup_id]

Operations:
  --target <stack|all>    Backup specified stack or all stacks
  --list                  List all available backups
  --restore <backup_id>   Restore from a specific backup
  --verify [backup_id]    Verify backup integrity (latest if no ID)

Options:
  --dry-run               Show what would be backed up without executing
  --help, -h              Show this help

Available stacks:
  base, network, storage, databases, media, monitoring,
  productivity, ai, sso, home-automation, notifications

Environment (set in .env or stacks/backup/.env):
  BACKUP_DIR              Local backup directory (default: /opt/homelab-backups)
  BACKUP_TARGET           Target: local|s3|b2|sftp|r2 (default: local)
  BACKUP_RETENTION_DAYS   Keep backups for N days (default: 7)
  BACKUP_ENCRYPT          Encrypt backups: true|false (default: false)

  # S3 / MinIO
  BACKUP_S3_ENDPOINT      S3 endpoint URL
  BACKUP_S3_BUCKET        Bucket name (default: homelab-backups)
  BACKUP_S3_ACCESS_KEY    Access key
  BACKUP_S3_SECRET_KEY    Secret key

  # Backblaze B2
  BACKUP_B2_BUCKET        B2 bucket name
  BACKUP_B2_KEY_ID        Application key ID
  BACKUP_B2_APPLICATION_KEY  Application key

  # SFTP
  BACKUP_SFTP_HOST        Server hostname
  BACKUP_SFTP_USER        Username
  BACKUP_SFTP_PATH        Remote path (default: /backups)

  # Cloudflare R2
  BACKUP_R2_ENDPOINT      R2 endpoint URL
  BACKUP_R2_BUCKET        Bucket name
  BACKUP_R2_ACCESS_KEY    Access key
  BACKUP_R2_SECRET_KEY    Secret key

Examples:
  backup.sh --target all
  backup.sh --target databases
  backup.sh --target all --dry-run
  backup.sh --list
  backup.sh --verify
  backup.sh --restore backup_20240315_020000
EOF
}

# --- Main dispatch ------------------------------------------------------------
main() {
    local operation=""
    local target=""
    local dry_run="false"
    local backup_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                operation="backup"; target="${2:-}"
                [[ -z "$target" ]] && { log_error "--target requires a stack name or 'all'"; exit 1; }
                shift 2 ;;
            --list) operation="list"; shift ;;
            --restore)
                operation="restore"; backup_id="${2:-}"
                [[ -z "$backup_id" ]] && { log_error "--restore requires a backup ID"; exit 1; }
                shift 2 ;;
            --verify)
                operation="verify"; backup_id="${2:-}"
                shift; [[ -n "$backup_id" && "$backup_id" != --* ]] && shift ;;
            --dry-run) dry_run="true"; shift ;;
            --help|-h) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    [[ -z "$operation" ]] && { usage; exit 1; }

    case "$operation" in
        backup)  do_backup "$target" "$dry_run" ;;
        list)    do_list ;;
        restore) do_restore "$backup_id" ;;
        verify)  do_verify "$backup_id" ;;
    esac
}

main "$@"
