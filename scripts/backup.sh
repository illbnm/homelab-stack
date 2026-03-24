#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 3-2-1 Backup Strategy
# Usage: backup.sh --target <all|media> [options]
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# -----------------------------------------------------------------------------
# Load Environment
# -----------------------------------------------------------------------------
load_env() {
  local env_files=(
    "$BASE_DIR/.env"
    "$BASE_DIR/stacks/backup/.env"
    "$BASE_DIR/config/.env"
  )
  
  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      log_debug "Loading: $env_file"
      # Export variables, handling quoted values
      set -a
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
          local key="${BASH_REMATCH[1]}"
          local value="${BASH_REMATCH[2]}"
          # Remove surrounding quotes
          value="${value#\"}"
          value="${value%\"}"
          value="${value#\'}"
          value="${value%\'}"
          export "$key=$value"
        fi
      done < "$env_file"
      set +a
    fi
  done
}

# -----------------------------------------------------------------------------
# Send ntfy Notification
# -----------------------------------------------------------------------------
send_notification() {
  local message="$1"
  local title="${2:-HomeLab Backup}"
  local priority="${3:-default}"
  
  if [[ -n "${NTFY_SERVER:-}" ]] && [[ -n "${NTFY_TOPIC:-}" ]]; then
    curl -s -S \
      -H "Title: $title" \
      -H "Priority: $priority" \
      -H "Tags: backup" \
      -d "$message" \
      "${NTFY_SERVER}/${NTFY_TOPIC}" >/dev/null 2>&1 || \
      log_warn "Failed to send ntfy notification"
  fi
}

# -----------------------------------------------------------------------------
# Get Restic Repository String
# -----------------------------------------------------------------------------
get_restic_repo() {
  case "${BACKUP_TARGET:-local}" in
    local)
      echo "rest:http://${RESTIC_SERVER_HOST:-restic-server}:${RESTIC_SERVER_PORT:-8000}"
      ;;
    s3)
      : "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID required for S3}"
      : "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY required for S3}"
      : "${S3_BUCKET_NAME:?S3_BUCKET_NAME required}"
      if [[ -n "${S3_ENDPOINT:-}" ]]; then
        echo "s3:${S3_ENDPOINT}/${S3_BUCKET_NAME}"
      else
        : "${AWS_REGION:?AWS_REGION required}"
        echo "s3:s3.${AWS_REGION}.amazonaws.com/${S3_BUCKET_NAME}"
      fi
      ;;
    b2)
      : "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID required for B2}"
      : "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY required for B2}"
      : "${B2_BUCKET_NAME:?B2_BUCKET_NAME required}"
      echo "b2:${B2_BUCKET_NAME}"
      ;;
    sftp)
      : "${SFTP_USER:?SFTP_USER required}"
      : "${SFTP_HOST:?SFTP_HOST required}"
      : "${SFTP_PATH:?SFTP_PATH required}"
      echo "sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}"
      ;;
    r2)
      : "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID required for R2}"
      : "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY required for R2}"
      : "${R2_ENDPOINT:?R2_ENDPOINT required}"
      : "${R2_BUCKET_NAME:?R2_BUCKET_NAME required}"
      echo "s3:${R2_ENDPOINT}/${R2_BUCKET_NAME}"
      ;;
    *)
      log_error "Unsupported BACKUP_TARGET: ${BACKUP_TARGET}"
      exit 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Run Restic in Docker Container
# -----------------------------------------------------------------------------
run_restic() {
  local cmd=("$@")
  local docker_args=("--rm")
  local volume_args=()
  
  # Network for local restic server
  if [[ "${BACKUP_TARGET:-local}" == "local" ]]; then
    docker_args+=("--network" "proxy")
  fi
  
  # Process volume mounts
  for arg in "$@"; do
    if [[ "$arg" == /* ]] && [[ -e "$arg" ]]; then
      local basename
      basename="$(basename "$arg")"
      volume_args+=("-v" "${arg}:/source/${basename}:ro")
    fi
  done
  
  # Environment variables for restic
  local env_args=(
    "-e" "RESTIC_PASSWORD=${RESTIC_PASSWORD}"
    "-e" "RESTIC_REPOSITORY=$(get_restic_repo)"
  )
  
  # Add cloud credentials
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && env_args+=("-e" "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}")
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] && env_args+=("-e" "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}")
  [[ -n "${AWS_REGION:-}" ]] && env_args+=("-e" "AWS_REGION=${AWS_REGION}")
  [[ -n "${B2_ACCOUNT_ID:-}" ]] && env_args+=("-e" "B2_ACCOUNT_ID=${B2_ACCOUNT_ID}")
  [[ -n "${B2_ACCOUNT_KEY:-}" ]] && env_args+=("-e" "B2_ACCOUNT_KEY=${B2_ACCOUNT_KEY}")
  [[ -n "${SFTP_USER:-}" ]] && env_args+=("-e" "SFTP_USER=${SFTP_USER}")
  [[ -n "${SFTP_PASSWORD:-}" ]] && env_args+=("-e" "SFTP_PASSWORD=${SFTP_PASSWORD}")
  [[ -n "${R2_ACCESS_KEY_ID:-}" ]] && env_args+=("-e" "AWS_ACCESS_KEY_ID=${R2_ACCESS_KEY_ID}")
  [[ -n "${R2_SECRET_ACCESS_KEY:-}" ]] && env_args+=("-e" "AWS_SECRET_ACCESS_KEY=${R2_SECRET_ACCESS_KEY}")
  
  log_debug "Running: docker run ${docker_args[*]} ${volume_args[*]} ${env_args[*]} restic/restic ${cmd[*]}"
  
  if [[ "${DRY_RUN:-0}" == "1" ]] && [[ "${cmd[0]}" != "snapshots" ]] && [[ "${cmd[0]}" != "check" ]]; then
    log_info "[DRY RUN] Would execute: restic ${cmd[*]}"
    return 0
  fi
  
  docker run "${docker_args[@]}" "${volume_args[@]}" "${env_args[@]}" \
    restic/restic:0.17.0 "${cmd[@]}"
}

# -----------------------------------------------------------------------------
# Get Volumes to Backup
# -----------------------------------------------------------------------------
get_volumes_to_backup() {
  local target="${1:-all}"
  local volumes=()
  
  # Common infrastructure volumes
  local infra_volumes=(
    "traefik-logs"
    "portainer-data"
    "authentik-data"
    "authentik-redis"
    "postgres-data"
    "redis-data"
    "mariadb-data"
  )
  
  # Media stack volumes
  local media_volumes=(
    "jellyfin-config"
    "sonarr-config"
    "radarr-config"
    "prowlarr-config"
    "qbittorrent-config"
    "jellyseerr-config"
  )
  
  # Productivity volumes
  local productivity_volumes=(
    "gitea-data"
    "vaultwarden-data"
    "outline-data"
    "bookstack-data"
  )
  
  # Storage volumes
  local storage_volumes=(
    "nextcloud-data"
    "nextcloud-db"
    "minio-data"
    "filebrowser-db"
  )
  
  # Home automation volumes
  local home_volumes=(
    "homeassistant-config"
    "nodered-data"
    "zigbee2mqtt-data"
  )
  
  # Monitoring volumes
  local monitoring_volumes=(
    "prometheus-data"
    "grafana-data"
    "loki-data"
    "alertmanager-data"
    "uptime-kuma-data"
  )
  
  # Network volumes
  local network_volumes=(
    "adguard-config"
    "wg-easy-config"
  )
  
  case "$target" in
    all)
      volumes=(
        "${infra_volumes[@]}"
        "${media_volumes[@]}"
        "${productivity_volumes[@]}"
        "${storage_volumes[@]}"
        "${home_volumes[@]}"
        "${monitoring_volumes[@]}"
        "${network_volumes[@]}"
      )
      ;;
    media)
      volumes=("${media_volumes[@]}")
      ;;
    infrastructure|base)
      volumes=("${infra_volumes[@]}")
      ;;
    productivity)
      volumes=("${productivity_volumes[@]}")
      ;;
    storage)
      volumes=("${storage_volumes[@]}")
      ;;
    home-automation)
      volumes=("${home_volumes[@]}")
      ;;
    monitoring)
      volumes=("${monitoring_volumes[@]}")
      ;;
    network)
      volumes=("${network_volumes[@]}")
      ;;
    *)
      log_error "Unknown target: $target"
      return 1
      ;;
  esac
  
  # Filter to only existing volumes
  local existing_volumes=()
  for vol in "${volumes[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
      existing_volumes+=("$vol")
    else
      log_debug "Volume not found, skipping: $vol"
    fi
  done
  
  printf '%s\n' "${existing_volumes[@]}"
}

# -----------------------------------------------------------------------------
# Backup Configs
# -----------------------------------------------------------------------------
backup_configs() {
  local backup_path="${1:-/tmp/homelab-configs}"
  
  log_info "Backing up configuration files..."
  
  mkdir -p "$backup_path"
  
  # Backup key config directories
  local config_dirs=(
    "$BASE_DIR/config"
    "$BASE_DIR/stacks"
    "$BASE_DIR/scripts"
    "$BASE_DIR/.env"
  )
  
  for dir in "${config_dirs[@]}"; do
    if [[ -e "$dir" ]]; then
      cp -a "$dir" "$backup_path/" 2>/dev/null || true
    fi
  done
  
  echo "$backup_path"
}

# -----------------------------------------------------------------------------
# Backup Databases
# -----------------------------------------------------------------------------
backup_databases() {
  local backup_path="${1:-/tmp/homelab-databases}"
  
  log_info "Backing up databases..."
  mkdir -p "$backup_path"
  
  # PostgreSQL
  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    log_info "  Backing up PostgreSQL..."
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | \
      grep -E '^POSTGRES_PASSWORD=' | cut -d= -f2 | head -1 || true)
    docker exec "$pg_container" sh -c "PGPASSWORD='${pg_pass}' pg_dumpall -U postgres" \
      > "$backup_path/postgresql_all.sql" 2>/dev/null || \
      log_warn "  PostgreSQL backup failed"
  fi
  
  # MariaDB/MySQL
  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    log_info "  Backing up MariaDB/MySQL..."
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | \
      grep -E '^MYSQL_ROOT_PASSWORD=' | cut -d= -f2 | head -1 || true)
    docker exec "$mysql_container" sh -c "mysqldump -u root -p'${mysql_pass}' --all-databases" \
      > "$backup_path/mysql_all.sql" 2>/dev/null || \
      log_warn "  MariaDB/MySQL backup failed"
  fi
  
  # Redis
  local redis_container
  redis_container=$(docker ps --format '{{.Names}}' | grep -E 'redis' | head -1 || true)
  if [[ -n "$redis_container" ]]; then
    log_info "  Backing up Redis..."
    docker exec "$redis_container" redis-cli BGSAVE 2>/dev/null || true
    sleep 2
    local redis_pass
    redis_pass=$(docker inspect "$redis_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | \
      grep -E '^REDIS_PASSWORD=' | cut -d= -f2 | head -1 || true)
    if [[ -n "$redis_pass" ]]; then
      docker exec "$redis_container" redis-cli -a "${redis_pass}" BGSAVE 2>/dev/null || true
    fi
  fi
  
  echo "$backup_path"
}

# -----------------------------------------------------------------------------
# Initialize Repository
# -----------------------------------------------------------------------------
init_repo() {
  log_info "Initializing restic repository..."
  
  if run_restic snapshots >/dev/null 2>&1; then
    log_info "Repository already initialized"
    return 0
  fi
  
  run_restic init
  log_info "Repository initialized successfully"
}

# -----------------------------------------------------------------------------
# Backup Command
# -----------------------------------------------------------------------------
do_backup() {
  local target="${1:-all}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  log_info "Starting backup for target: $target"
  send_notification "Backup started for target: $target" "HomeLab Backup" "low"
  
  # Check required variables
  : "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required}"
  
  # Initialize repository if needed
  init_repo
  
  # Create temp backup directory
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Backup configs
  local config_backup
  config_backup=$(backup_configs "$temp_dir/configs")
  
  # Backup databases
  local db_backup
  db_backup=$(backup_databases "$temp_dir/databases")
  
  # Get volumes to backup
  local volumes
  mapfile -t volumes < <(get_volumes_to_backup "$target")
  
  if [[ ${#volumes[@]} -eq 0 ]]; then
    log_warn "No volumes found to backup"
  fi
  
  # Backup volumes
  for vol in "${volumes[@]}"; do
    local mount_point
    mount_point=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || true)
    if [[ -n "$mount_point" ]] && [[ -d "$mount_point" ]]; then
      log_info "  Backing up volume: $vol"
      run_restic backup "$mount_point" --tag "$target" --tag "$vol" --tag "homelab"
    fi
  done
  
  # Backup configs and databases
  if [[ -d "$temp_dir" ]]; then
    log_info "  Backing up configs and databases"
    run_restic backup "$temp_dir" --tag "$target" --tag "configs" --tag "homelab"
    rm -rf "$temp_dir"
  fi
  
  # Prune old backups
  log_info "Pruning old backups..."
  run_restic forget ${RESTIC_RETENTION_POLICY:---keep-daily 7 --keep-weekly 4 --keep-monthly 6}
  run_restic prune
  
  log_info "Backup completed successfully"
  send_notification "Backup completed for target: $target" "HomeLab Backup" "default"
}

# -----------------------------------------------------------------------------
# Restore Command
# -----------------------------------------------------------------------------
do_restore() {
  local backup_id="${1:?Backup ID required}"
  local restore_path="${2:?Restore path required}"
  
  log_info "Restoring backup $backup_id to $restore_path"
  
  mkdir -p "$restore_path"
  
  # For restore, we need to mount the restore path
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Download to temp dir first
  docker run --rm \
    --network proxy \
    -e "RESTIC_PASSWORD=${RESTIC_PASSWORD}" \
    -e "RESTIC_REPOSITORY=$(get_restic_repo)" \
    -v "$temp_dir:/restore" \
    restic/restic:0.17.0 restore "$backup_id" --target /restore
  
  # Copy to final destination
  cp -a "$temp_dir"/* "$restore_path/" 2>/dev/null || true
  rm -rf "$temp_dir"
  
  log_info "Restore completed to: $restore_path"
  send_notification "Restore completed to: $restore_path" "HomeLab Backup" "high"
}

# -----------------------------------------------------------------------------
# List Command
# -----------------------------------------------------------------------------
do_list() {
  log_info "Listing all backups..."
  run_restic snapshots
}

# -----------------------------------------------------------------------------
# Verify Command
# -----------------------------------------------------------------------------
do_verify() {
  log_info "Verifying backup integrity..."
  run_restic check --read-data
  log_info "Verification completed"
  send_notification "Backup verification completed" "HomeLab Backup" "default"
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
show_help() {
  cat << EOF
HomeLab Backup — 3-2-1 Backup Strategy

Usage:
  backup.sh --target <all|media|stack> [options]
  backup.sh --list
  backup.sh --verify
  backup.sh --restore <backup_id> --target <path>

Commands:
  --target <stack>     Backup specified stack (all, media, base, storage, etc.)
  --dry-run            Show what would be backed up without executing
  --restore <id>       Restore from specified backup ID
  --target <path>      Target path for restore operation
  --list               List all available backups
  --verify             Verify backup repository integrity
  --help               Show this help message

Backup Targets:
  local                Restic REST Server (default)
  s3                   AWS S3 or MinIO
  b2                   Backblaze B2
  sftp                 SFTP server
  r2                   Cloudflare R2

Environment Variables:
  BACKUP_TARGET        Backup destination (local, s3, b2, sftp, r2)
  RESTIC_PASSWORD      Repository encryption password (required)
  RESTIC_RETENTION_POLICY  Retention policy (default: 7 daily, 4 weekly, 6 monthly)

Examples:
  # Backup all stacks
  ./backup.sh --target all

  # Backup only media stack
  ./backup.sh --target media

  # Dry run
  ./backup.sh --target all --dry-run

  # List backups
  ./backup.sh --list

  # Restore
  ./backup.sh --restore abc123 --target /tmp/restore

Generated/reviewed with: claude-opus-4-6
EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  local target=""
  local action="backup"
  local restore_id=""
  local restore_path=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        target="$2"
        shift 2
        ;;
      --dry-run)
        export DRY_RUN=1
        shift
        ;;
      --restore)
        action="restore"
        restore_id="$2"
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
        show_help
        exit 0
        ;;
      --debug)
        export DEBUG=1
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Load environment
  load_env
  
  # Execute action
  case "$action" in
    backup)
      if [[ -z "$target" ]]; then
        log_error "--target is required for backup"
        show_help
        exit 1
      fi
      do_backup "$target"
      ;;
    restore)
      if [[ -z "$restore_id" ]] || [[ -z "$target" ]]; then
        log_error "--restore <id> and --target <path> are required"
        show_help
        exit 1
      fi
      do_restore "$restore_id" "$target"
      ;;
    list)
      do_list
      ;;
    verify)
      do_verify
      ;;
  esac
}

main "$@"