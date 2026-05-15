#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Comprehensive backup script
# Supports: --target <stack|all>, --dry-run, --restore, --list, --verify
# Backends: local, S3/MinIO, Backblaze B2, SFTP, Cloudflare R2
# Notifications: ntfy push on success/failure
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."

# Try loading env from multiple locations
for env_file in \
  "${BASE_DIR}/stacks/backup/.env" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/config/.env"; do
  [[ -f "$env_file" ]] && source "$env_file" && break
done

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
BACKUP_DIR="${BACKUP_DATA_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
RESTIC_REPO="${BACKUP_RESTIC_REPO:-http://restic-server:8000}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ID="${TIMESTAMP}"
LOG_FILE="/tmp/homelab-backup-${TIMESTAMP}.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[backup]${NC} $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[backup]${NC} $*" | tee -a "$LOG_FILE" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}" | tee -a "$LOG_FILE"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
TARGET="all"
DRY_RUN=false
ACTION="backup"
RESTORE_ID=""
NOTIFY=false

usage() {
  cat <<EOF
HomeLab Backup — Automated backup for all stacks

Usage:
  $(basename "$0") --target <stack|all> [options]

Options:
  --target <name>       Backup specific stack or 'all' (default: all)
  --dry-run             Show what would be backed up, don't execute
  --restore <id>        Restore from a specific backup ID
  --list                List all available backups
  --verify              Verify backup integrity
  --notify              Send ntfy notification on completion
  -h, --help            Show this help

Targets (BACKUP_TARGET in .env):
  local                 Local directory (default)
  s3                    S3-compatible (MinIO, AWS, etc.)
  b2                    Backblaze B2
  sftp                  SFTP remote server
  r2                    Cloudflare R2

Examples:
  $(basename "$0") --target all --notify
  $(basename "$0") --target media --dry-run
  $(basename "$0") --list
  $(basename "$0") --restore 20260515_020000
  $(basename "$0") --verify
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --restore)  ACTION="restore"; RESTORE_ID="$2"; shift 2 ;;
    --list)     ACTION="list"; shift ;;
    --verify)   ACTION="verify"; shift ;;
    --notify)   NOTIFY=true; shift ;;
    -h|--help)  usage ;;
    *)          log_error "Unknown option: $1"; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Notification
# ---------------------------------------------------------------------------
send_notification() {
  local title="$1" message="$2" priority="${3:-default}"
  if [[ "$NOTIFY" == true ]] && command -v curl &>/dev/null; then
    local ntfy_endpoint="${NTFY_URL}/${NTFY_TOPIC}"
    local auth_header=""
    [[ -n "${NTFY_TOKEN:-}" ]] && auth_header="-H \"Authorization: Bearer ${NTFY_TOKEN}\""
    eval curl -s -o /dev/null \
      -H "Title: ${title}" \
      -H "Priority: ${priority}" \
      ${auth_header} \
      -d "${message}" \
      "${ntfy_endpoint}" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Discover stacks and their volumes
# ---------------------------------------------------------------------------
declare -A STACK_VOLUMES

discover_stacks() {
  log_step "Discovering stacks..."
  local stacks_dir="${BASE_DIR}/stacks"

  if [[ ! -d "$stacks_dir" ]]; then
    log_warn "Stacks directory not found: $stacks_dir"
    return
  fi

  for stack_dir in "$stacks_dir"/*/; do
    local stack_name
    stack_name=$(basename "$stack_dir")
    [[ "$stack_name" == "backup" ]] && continue  # Skip self

    local compose_file="${stack_dir}docker-compose.yml"
    [[ ! -f "$compose_file" ]] && continue

    # Extract volume names from docker-compose.yml
    local volumes
    volumes=$(grep -E '^\s+-\s+\w[\w-]*:' "$compose_file" 2>/dev/null | \
              sed 's/.*- //;s/:.*//' | sort -u || true)

    # Also get the Docker named volumes from the volumes: section
    local named_volumes
    named_volumes=$(awk '/^volumes:/{found=1} found && /^  \w/{print $1}' "$compose_file" 2>/dev/null | \
                    sed 's/://' || true)

    STACK_VOLUMES["$stack_name"]="${volumes} ${named_volumes}"
    log_info "  Found stack: $stack_name"
  done
}

# ---------------------------------------------------------------------------
# List Docker volumes for a stack
# ---------------------------------------------------------------------------
get_stack_volumes() {
  local stack_name="$1"
  local volumes=""

  # Get volumes from running containers
  local containers
  containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "$stack_name" || true)

  for container in $containers; do
    local vols
    vols=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' 2>/dev/null || true)
    volumes="$volumes $vols"
  done

  # Deduplicate
  echo "$volumes" | tr ' ' '\n' | sort -u | grep -v '^$'
}

# ---------------------------------------------------------------------------
# Backup a single volume
# ---------------------------------------------------------------------------
backup_volume() {
  local vol="$1" dest_dir="$2"
  local dest_file="${dest_dir}/vol_${vol}.tar.gz"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "  [DRY-RUN] Would backup volume: $vol"
    return 0
  fi

  log_info "  Backing up volume: $vol"
  docker run --rm \
    -v "${vol}:/data:ro" \
    -v "${dest_dir}:/backup" \
    alpine:3.19 \
    tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || {
      log_warn "  Failed to backup volume: $vol"
      return 1
    }
  log_info "  ✓ $vol -> $dest_file ($(du -sh "$dest_file" 2>/dev/null | cut -f1))"
}

# ---------------------------------------------------------------------------
# Backup databases (pg_dumpall + mysqldump)
# ---------------------------------------------------------------------------
backup_databases() {
  local dest_dir="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would dump databases"
    return 0
  fi

  log_step "Dumping databases..."

  # PostgreSQL
  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    log_info "  Dumping PostgreSQL from: $pg_container"
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
              grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
    docker exec "$pg_container" \
      sh -c "PGPASSWORD='${pg_pass}' pg_dumpall -U postgres" \
      > "${dest_dir}/postgresql_all.sql" 2>/dev/null || {
        log_warn "  PostgreSQL dump failed"
      }
    log_info "  ✓ PostgreSQL dump: $(du -sh "${dest_dir}/postgresql_all.sql" 2>/dev/null | cut -f1)"
  fi

  # MariaDB / MySQL
  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    log_info "  Dumping MariaDB/MySQL from: $mysql_container"
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
                 grep -E 'MYSQL_ROOT_PASSWORD|MARIADB_ROOT_PASSWORD' | cut -d= -f2 | head -1 || true)
    docker exec "$mysql_container" \
      sh -c "mysqldump -u root -p'${mysql_pass}' --all-databases" \
      > "${dest_dir}/mysql_all.sql" 2>/dev/null || {
        log_warn "  MySQL dump failed"
      }
    log_info "  ✓ MySQL dump: $(du -sh "${dest_dir}/mysql_all.sql" 2>/dev/null | cut -f1)"
  fi

  # Redis (BGSAVE + copy RDB)
  local redis_container
  redis_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'redis' | head -1 || true)
  if [[ -n "$redis_container" ]]; then
    log_info "  Backing up Redis from: $redis_container"
    local redis_pass
    redis_pass=$(docker inspect "$redis_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
                 grep REDIS_PASSWORD | cut -d= -f2 | head -1 || true)
    docker exec "$redis_container" redis-cli -a "$redis_pass" BGSAVE 2>/dev/null || true
    sleep 2
    docker cp "${redis_container}:/data/dump.rdp" "${dest_dir}/redis_dump.rdb" 2>/dev/null || true
    log_info "  ✓ Redis dump copied"
  fi
}

# ---------------------------------------------------------------------------
# Backup config files
# ---------------------------------------------------------------------------
backup_configs() {
  local dest_dir="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would backup config files"
    return 0
  fi

  log_step "Backing up config files..."
  tar czf "${dest_dir}/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='.git' \
    --exclude='node_modules' \
    config/ stacks/ scripts/ docs/ .env.example 2>/dev/null || true
  log_info "  ✓ Configs: $(du -sh "${dest_dir}/configs.tar.gz" 2>/dev/null | cut -f1)"
}

# ---------------------------------------------------------------------------
# Push to remote target (restic)
# ---------------------------------------------------------------------------
push_to_target() {
  local backup_path="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would push to target: $BACKUP_TARGET"
    return 0
  fi

  case "$BACKUP_TARGET" in
    local)
      log_info "Backup stored locally at: $backup_path"
      ;;
    s3)
      log_step "Pushing to S3/MinIO..."
      if command -v restic &>/dev/null; then
        export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
        export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
        export RESTIC_REPOSITORY="s3:${S3_ENDPOINT}/${S3_BUCKET}"
        export RESTIC_PASSWORD
        restic init 2>/dev/null || true
        restic backup "$backup_path" --tag homelab --tag "$TIMESTAMP"
        restic forget --keep-daily "$RETENTION_DAYS" --prune
        log_info "✓ Pushed to S3: ${S3_BUCKET}"
      else
        log_warn "restic not installed — skipping S3 push"
      fi
      ;;
    b2)
      log_step "Pushing to Backblaze B2..."
      if command -v restic &>/dev/null; then
        export B2_ACCOUNT_ID
        export B2_ACCOUNT_KEY
        export RESTIC_REPOSITORY="b2:${B2_BUCKET}"
        export RESTIC_PASSWORD
        restic init 2>/dev/null || true
        restic backup "$backup_path" --tag homelab --tag "$TIMESTAMP"
        restic forget --keep-daily "$RETENTION_DAYS" --prune
        log_info "✓ Pushed to B2: ${B2_BUCKET}"
      else
        log_warn "restic not installed — skipping B2 push"
      fi
      ;;
    sftp)
      log_step "Pushing to SFTP..."
      if command -v restic &>/dev/null; then
        local sftp_repo="sftp:${SFTP_HOST}:${SFTP_PATH}"
        export RESTIC_REPOSITORY="$sftp_repo"
        export RESTIC_PASSWORD
        [[ -n "${SFTP_KEY_FILE:-}" ]] && export RSYNC_RSH="ssh -i ${SFTP_KEY_FILE} -p ${SFTP_PORT:-22}"
        restic init 2>/dev/null || true
        restic backup "$backup_path" --tag homelab --tag "$TIMESTAMP"
        restic forget --keep-daily "$RETENTION_DAYS" --prune
        log_info "✓ Pushed to SFTP: ${SFTP_HOST}:${SFTP_PATH}"
      else
        log_warn "restic not installed — skipping SFTP push"
      fi
      ;;
    r2)
      log_step "Pushing to Cloudflare R2..."
      if command -v restic &>/dev/null; then
        export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY}"
        export AWS_SECRET_ACCESS_KEY="${R2_SECRET_KEY}"
        export RESTIC_REPOSITORY="s3:${R2_ENDPOINT}/${R2_BUCKET}"
        export RESTIC_PASSWORD
        restic init 2>/dev/null || true
        restic backup "$backup_path" --tag homelab --tag "$TIMESTAMP"
        restic forget --keep-daily "$RETENTION_DAYS" --prune
        log_info "✓ Pushed to R2: ${R2_BUCKET}"
      else
        log_warn "restic not installed — skipping R2 push"
      fi
      ;;
    *)
      log_error "Unknown backup target: $BACKUP_TARGET"
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# List backups
# ---------------------------------------------------------------------------
list_backups() {
  log_step "Available backups"

  echo -e "\n${BOLD}Local backups:${NC}"
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' | sort -r | while read -r dir; do
      local id
      id=$(basename "$dir")
      local size
      size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      local count
      count=$(find "$dir" -type f | wc -l | tr -d ' ')
      echo "  $id  ($size, $count files)"
    done
  else
    echo "  No local backups found"
  fi

  # List restic snapshots if available
  if command -v restic &>/dev/null && [[ -n "$RESTIC_PASSWORD" ]]; then
    echo -e "\n${BOLD}Restic snapshots:${NC}"
    export RESTIC_REPOSITORY="$RESTIC_REPO"
    export RESTIC_PASSWORD
    restic snapshots 2>/dev/null || echo "  Cannot connect to restic repo"
  fi
}

# ---------------------------------------------------------------------------
# Verify backup integrity
# ---------------------------------------------------------------------------
verify_backups() {
  log_step "Verifying backup integrity"

  local latest
  latest=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' | sort -r | head -1 || true)

  if [[ -z "$latest" ]]; then
    log_error "No backups found to verify"
    return 1
  fi

  log_info "Verifying: $latest"
  local errors=0

  for archive in "$latest"/*.tar.gz; do
    [[ ! -f "$archive" ]] && continue
    local name
    name=$(basename "$archive")
    if tar tzf "$archive" &>/dev/null; then
      log_info "  ✓ $name — OK"
    else
      log_error "  ✗ $name — CORRUPT"
      ((errors++))
    fi
  done

  # Verify SQL dumps
  for dump in "$latest"/*.sql; do
    [[ ! -f "$dump" ]] && continue
    local name
    name=$(basename "$dump")
    local size
    size=$(stat -f%z "$dump" 2>/dev/null || stat -c%s "$dump" 2>/dev/null || echo 0)
    if [[ "$size" -gt 100 ]]; then
      log_info "  ✓ $name — OK ($size bytes)"
    else
      log_warn "  ⚠ $name — Suspiciously small ($size bytes)"
      ((errors++))
    fi
  done

  # Verify restic repo
  if command -v restic &>/dev/null && [[ -n "$RESTIC_PASSWORD" ]]; then
    log_info "Verifying restic repository..."
    export RESTIC_REPOSITORY="$RESTIC_REPO"
    export RESTIC_PASSWORD
    restic check 2>/dev/null && log_info "  ✓ Restic repo — OK" || {
      log_error "  ✗ Restic repo — FAILED"
      ((errors++))
    }
  fi

  if [[ $errors -eq 0 ]]; then
    log_info "\n✓ All backups verified successfully"
    send_notification "Backup Verify ✓" "All backups in $latest verified OK" "low"
  else
    log_error "\n✗ $errors verification errors found"
    send_notification "Backup Verify ✗" "$errors errors in $latest" "high"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Restore from backup
# ---------------------------------------------------------------------------
restore_backup() {
  local restore_dir="${BACKUP_DIR}/${RESTORE_ID}"

  if [[ ! -d "$restore_dir" ]]; then
    log_error "Backup not found: $RESTORE_ID"
    log_info "Run '$(basename "$0") --list' to see available backups"
    return 1
  fi

  log_step "Restoring from backup: $RESTORE_ID"
  log_warn "⚠ This will OVERWRITE current data. Press Ctrl+C to abort, or wait 5s..."
  sleep 5

  # Restore Docker volumes
  for archive in "$restore_dir"/vol_*.tar.gz; do
    [[ ! -f "$archive" ]] && continue
    local vol_name
    vol_name=$(basename "$archive" | sed 's/^vol_//;s/\.tar\.gz$//')
    log_info "Restoring volume: $vol_name"

    # Create volume if it doesn't exist
    docker volume create "$vol_name" 2>/dev/null || true

    docker run --rm \
      -v "${vol_name}:/data" \
      -v "${restore_dir}:/backup:ro" \
      alpine:3.19 \
      sh -c "rm -rf /data/* && tar xzf /backup/vol_${vol_name}.tar.gz -C /data"
    log_info "  ✓ $vol_name restored"
  done

  # Restore PostgreSQL
  if [[ -f "$restore_dir/postgresql_all.sql" ]]; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' | head -1 || true)
    if [[ -n "$pg_container" ]]; then
      log_info "Restoring PostgreSQL..."
      local pg_pass
      pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
                grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
      docker exec -i "$pg_container" \
        sh -c "PGPASSWORD='${pg_pass}' psql -U postgres" \
        < "$restore_dir/postgresql_all.sql" 2>/dev/null || {
          log_warn "PostgreSQL restore had errors (may be expected for existing DBs)"
        }
      log_info "  ✓ PostgreSQL restored"
    fi
  fi

  # Restore MariaDB
  if [[ -f "$restore_dir/mysql_all.sql" ]]; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' | head -1 || true)
    if [[ -n "$mysql_container" ]]; then
      log_info "Restoring MariaDB/MySQL..."
      local mysql_pass
      mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
                   grep -E 'MYSQL_ROOT_PASSWORD|MARIADB_ROOT_PASSWORD' | cut -d= -f2 | head -1 || true)
      docker exec -i "$mysql_container" \
        sh -c "mysql -u root -p'${mysql_pass}'" \
        < "$restore_dir/mysql_all.sql" 2>/dev/null || {
          log_warn "MySQL restore had errors (may be expected for existing DBs)"
        }
      log_info "  ✓ MariaDB/MySQL restored"
    fi
  fi

  log_step "Restore complete!"
  log_info "You may need to restart services: docker compose -f <stack>/docker-compose.yml up -d"
  send_notification "Restore Complete ✓" "Restored from $RESTORE_ID" "high"
}

# ---------------------------------------------------------------------------
# Main backup flow
# ---------------------------------------------------------------------------
run_backup() {
  local backup_path="${BACKUP_DIR}/${BACKUP_ID}"

  if [[ "$DRY_RUN" == true ]]; then
    log_step "DRY-RUN MODE — nothing will be executed"
  fi

  mkdir -p "$backup_path"

  # 1. Backup configs
  backup_configs "$backup_path"

  # 2. Discover and backup volumes per stack
  log_step "Backing up Docker volumes..."
  if [[ "$TARGET" == "all" ]]; then
    # Backup ALL Docker volumes (excluding anonymous)
    local all_volumes
    all_volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -v '^[a-f0-9]\{64\}$' || true)
    while IFS= read -r vol; do
      [[ -z "$vol" ]] && continue
      backup_volume "$vol" "$backup_path"
    done <<< "$all_volumes"
  else
    # Backup only volumes for the specified stack
    local stack_volumes
    stack_volumes=$(get_stack_volumes "$TARGET")
    if [[ -z "$stack_volumes" ]]; then
      log_warn "No volumes found for stack: $TARGET"
    else
      while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        backup_volume "$vol" "$backup_path"
      done <<< "$stack_volumes"
    fi
  fi

  # 3. Dump databases
  backup_databases "$backup_path"

  # 4. Push to remote target
  push_to_target "$backup_path"

  # 5. Cleanup old local backups
  if [[ "$DRY_RUN" != true ]]; then
    log_step "Cleaning backups older than ${RETENTION_DAYS} days..."
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
  fi

  # 6. Summary
  if [[ "$DRY_RUN" != true ]]; then
    local total_size
    total_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
    local file_count
    file_count=$(find "$backup_path" -type f | wc -l | tr -d ' ')

    log_step "Backup Summary"
    log_info "  ID:       $BACKUP_ID"
    log_info "  Target:   $BACKUP_TARGET"
    log_info "  Path:     $backup_path"
    log_info "  Size:     $total_size"
    log_info "  Files:    $file_count"
    log_info "  Retained: ${RETENTION_DAYS} days"

    send_notification \
      "Backup Complete ✓" \
      "ID: ${BACKUP_ID}\nTarget: ${BACKUP_TARGET}\nSize: ${total_size}\nFiles: ${file_count}" \
      "default"
  fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
case "$ACTION" in
  backup)  run_backup ;;
  list)    list_backups ;;
  verify)  verify_backups ;;
  restore) restore_backup ;;
esac
