#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — 3-2-1 strategy: 3 copies, 2 media types, 1 offsite
#
# Usage:
#   backup.sh --target <stack|all> [options]
#
# Options:
#   --target all          Backup all stack data volumes
#   --target media        Backup only the media stack
#   --target databases    Backup only the databases stack
#   --dry-run             Show what would be backed up without executing
#   --restore <backup_id> Restore from a specific backup
#   --list                List all available backups
#   --verify              Verify backup integrity
#   --encrypt             Enable AES-256-CBC encryption
#   --help                Show this help
#
# Environment:
#   BACKUP_TARGET=local|s3|b2|sftp|r2   Storage backend (default: local)
#   BACKUP_DIR=/opt/homelab-backups      Local backup directory
#   BACKUP_RETENTION_DAYS=7              Days to keep backups
#   BACKUP_ENCRYPTION_KEY=<passphrase>   Encryption passphrase (optional)
#   NTFY_URL=https://ntfy.sh/homelab     ntfy notification URL
#   S3_ENDPOINT=<url>                    S3/MinIO/R2 endpoint
#   S3_BUCKET=<name>                     S3 bucket name
#   S3_ACCESS_KEY=<key>                  S3 access key
#   S3_SECRET_KEY=<secret>               S3 secret key
#   B2_ACCOUNT_ID=<id>                   Backblaze B2 account ID
#   B2_APP_KEY=<key>                     Backblaze B2 application key
#   B2_BUCKET=<name>                     B2 bucket name
#   SFTP_HOST=<host>                     SFTP host
#   SFTP_USER=<user>                     SFTP user
#   SFTP_PATH=<path>                     SFTP remote path
#   SFTP_KEY=<path>                      SFTP private key path
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."

# Load environment
for envfile in "$BASE_DIR/config/.env" "$BASE_DIR/.env"; do
  if [[ -f "$envfile" ]]; then
    # shellcheck source=/dev/null
    source "$envfile"
    break
  fi
done

# Defaults
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
DRY_RUN=false
DO_ENCRYPT=false
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[backup]${NC} $*"; }

# ---------------------------------------------------------------------------
# Notification
# ---------------------------------------------------------------------------
notify() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"

  # ntfy
  if [[ -n "${NTFY_URL:-}" ]]; then
    curl -sf \
      -H "Title: $title" \
      -H "Priority: $priority" \
      -d "$message" \
      "$NTFY_URL" >/dev/null 2>&1 || true
  fi

  # Gotify
  if [[ -n "${GOTIFY_URL:-}" && -n "${GOTIFY_TOKEN:-}" ]]; then
    curl -sf \
      -X POST "${GOTIFY_URL}/message" \
      -H "X-Gotify-Key: $GOTIFY_TOKEN" \
      -F "title=$title" \
      -F "message=$message" \
      -F "priority=5" >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  echo "HomeLab Backup — 3-2-1 Strategy"
  echo ""
  echo "Usage: $0 --target <stack|all> [options]"
  echo ""
  echo "Targets:"
  echo "  all           Backup all stack data volumes"
  echo "  databases     Backup databases stack"
  echo "  storage       Backup storage stack"
  echo "  media         Backup media stack"
  echo "  base          Backup base stack"
  echo "  ai            Backup AI stack"
  echo "  sso           Backup SSO stack"
  echo "  monitoring    Backup monitoring stack"
  echo "  productivity  Backup productivity stack"
  echo ""
  echo "Options:"
  echo "  --dry-run             Show what would be backed up"
  echo "  --restore <backup_id> Restore from backup (e.g., 20260318_020000)"
  echo "  --list                List available backups"
  echo "  --verify              Verify backup integrity"
  echo "  --encrypt             Enable AES-256-CBC encryption"
  echo "  --help                Show this help"
  echo ""
  echo "Environment: BACKUP_TARGET=local|s3|b2|sftp|r2"
  exit 0
}

# ---------------------------------------------------------------------------
# Discover volumes for a stack
# ---------------------------------------------------------------------------
get_stack_volumes() {
  local stack="$1"
  local compose_file="$BASE_DIR/stacks/$stack/docker-compose.yml"

  if [[ ! -f "$compose_file" ]]; then
    log_warn "Compose file not found: $compose_file"
    return
  fi

  # Extract named volumes from compose file
  docker compose -f "$compose_file" config --format json 2>/dev/null \
    | jq -r '.volumes // {} | keys[]' 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Backup a single Docker volume
# ---------------------------------------------------------------------------
backup_volume() {
  local vol="$1"
  local dest="$2"
  local archive="vol_${vol}.tar.gz"

  if $DRY_RUN; then
    log_info "  [dry-run] Would backup volume: $vol → $archive"
    return
  fi

  log_info "  Volume: $vol"
  docker run --rm \
    -v "${vol}:/data:ro" \
    -v "$dest:/backup" \
    alpine:3.19 \
    tar czf "/backup/$archive" -C /data . 2>/dev/null || {
      log_warn "  Failed to backup volume: $vol"
      return 1
    }

  if $DO_ENCRYPT && [[ -n "$ENCRYPTION_KEY" ]]; then
    encrypt_file "$dest/$archive"
  fi
}

# ---------------------------------------------------------------------------
# Backup databases (PostgreSQL, MariaDB, Redis)
# ---------------------------------------------------------------------------
backup_databases() {
  local dest="$1"

  if $DRY_RUN; then
    log_info "  [dry-run] Would backup PostgreSQL, MariaDB, Redis"
    return
  fi

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
    log_info "  PostgreSQL: pg_dumpall..."
    local pg_user
    pg_user=$(docker exec homelab-postgres printenv POSTGRES_USER 2>/dev/null || echo "postgres")
    docker exec homelab-postgres \
      pg_dumpall -U "$pg_user" 2>/dev/null \
      | gzip > "$dest/postgresql_all.sql.gz" || \
      log_warn "  PostgreSQL backup failed"
  fi

  # MariaDB
  if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
    log_info "  MariaDB: mysqldump..."
    local maria_pass
    maria_pass=$(docker exec homelab-mariadb printenv MARIADB_ROOT_PASSWORD 2>/dev/null || echo "")
    if [[ -n "$maria_pass" ]]; then
      docker exec homelab-mariadb \
        mariadb-dump --all-databases -u root -p"$maria_pass" 2>/dev/null \
        | gzip > "$dest/mariadb_all.sql.gz" || \
        log_warn "  MariaDB backup failed"
    fi
  fi

  # Redis
  if docker ps --format '{{.Names}}' | grep -q 'homelab-redis'; then
    log_info "  Redis: BGSAVE + dump.rdb..."
    local redis_pass
    redis_pass=$(docker inspect --format='{{json .Config.Cmd}}' homelab-redis 2>/dev/null \
      | jq -r '. as $a | range(length) | select($a[.] == "--requirepass") | $a[. + 1] // empty' 2>/dev/null) || redis_pass=""
    local redis_cli_args=()
    if [[ -n "$redis_pass" ]]; then
      redis_cli_args=(-a "$redis_pass" --no-auth-warning)
    fi
    # Record LASTSAVE before triggering BGSAVE
    local last_save_before
    last_save_before=$(docker exec homelab-redis redis-cli "${redis_cli_args[@]}" LASTSAVE 2>/dev/null | tr -d '[:space:]')
    docker exec homelab-redis redis-cli "${redis_cli_args[@]}" BGSAVE >/dev/null 2>&1
    # Poll until LASTSAVE changes (save complete)
    for _wait in $(seq 1 30); do
      local last_save_now
      last_save_now=$(docker exec homelab-redis redis-cli "${redis_cli_args[@]}" LASTSAVE 2>/dev/null | tr -d '[:space:]')
      if [[ "$last_save_now" != "$last_save_before" ]]; then break; fi
      sleep 1
    done
    docker cp homelab-redis:/data/dump.rdb "$dest/redis_dump.rdb" 2>/dev/null || \
      log_warn "  Redis backup failed"
  fi

  # Encrypt DB dumps
  if $DO_ENCRYPT && [[ -n "$ENCRYPTION_KEY" ]]; then
    for f in "$dest"/*.sql.gz "$dest"/*.rdb; do
      [[ -f "$f" ]] && encrypt_file "$f"
    done
  fi
}

# ---------------------------------------------------------------------------
# Backup configs
# ---------------------------------------------------------------------------
backup_configs() {
  local dest="$1"

  if $DRY_RUN; then
    log_info "  [dry-run] Would backup config/ stacks/ scripts/"
    return
  fi

  log_info "  Configs: config/ stacks/ scripts/"
  tar czf "$dest/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='*.log' \
    config/ stacks/ scripts/ 2>/dev/null || \
    log_warn "  Config backup failed"

  if $DO_ENCRYPT && [[ -n "$ENCRYPTION_KEY" ]]; then
    encrypt_file "$dest/configs.tar.gz"
  fi
}

# ---------------------------------------------------------------------------
# Encryption (AES-256-CBC)
# ---------------------------------------------------------------------------
encrypt_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then return; fi

  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -in "$file" \
    -out "${file}.enc" \
    -pass "pass:$ENCRYPTION_KEY" 2>/dev/null && \
  rm -f "$file" && \
  log_info "  Encrypted: $(basename "${file}.enc")"
}

decrypt_file() {
  local file="$1"
  local out="${file%.enc}"

  openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
    -in "$file" \
    -out "$out" \
    -pass "pass:$ENCRYPTION_KEY" 2>/dev/null || {
      log_error "Failed to decrypt: $file"
      return 1
    }
  log_info "  Decrypted: $(basename "$out")"
}

# ---------------------------------------------------------------------------
# Upload to remote target
# ---------------------------------------------------------------------------
upload_backup() {
  local src="$1"
  local backup_id
  backup_id=$(basename "$src")

  case "$BACKUP_TARGET" in
    local)
      log_info "Backup stored locally: $src"
      ;;

    s3)
      log_step "Uploading to S3: ${S3_BUCKET}/${backup_id}/"
      if $DRY_RUN; then
        log_info "[dry-run] Would upload to s3://${S3_BUCKET}/${backup_id}/"
        return
      fi
      if command -v aws >/dev/null 2>&1; then
        AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
        AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
        aws s3 cp --recursive "$src/" "s3://${S3_BUCKET}/${backup_id}/" \
          --endpoint-url "${S3_ENDPOINT}" 2>&1 || { log_error "S3 upload failed"; return 1; }
      elif command -v mc >/dev/null 2>&1; then
        mc alias set backup "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}" --api s3v4 >/dev/null 2>&1
        mc cp --recursive "$src/" "backup/${S3_BUCKET}/${backup_id}/" 2>&1 || { log_error "MinIO upload failed"; return 1; }
      else
        log_error "No S3 client found. Install awscli or minio-client (mc)."
        return 1
      fi
      ;;

    b2)
      log_step "Uploading to Backblaze B2: ${B2_BUCKET}/${backup_id}/"
      if $DRY_RUN; then
        log_info "[dry-run] Would upload to b2://${B2_BUCKET}/${backup_id}/"
        return
      fi
      if command -v b2 >/dev/null 2>&1; then
        b2 authorize-account "${B2_ACCOUNT_ID}" "${B2_APP_KEY}" >/dev/null 2>&1
        for f in "$src"/*; do
          [[ -f "$f" ]] || continue
          b2 upload-file "${B2_BUCKET}" "$f" "${backup_id}/$(basename "$f")" >/dev/null 2>&1 || \
            log_warn "B2 upload failed: $(basename "$f")"
        done
      else
        log_error "b2 CLI not found. Install backblaze-b2."
        return 1
      fi
      ;;

    sftp)
      log_step "Uploading via SFTP to ${SFTP_HOST}:${SFTP_PATH}/${backup_id}/"
      if $DRY_RUN; then
        log_info "[dry-run] Would upload to ${SFTP_HOST}:${SFTP_PATH}/${backup_id}/"
        return
      fi
      local ssh_opts="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
      if [[ -n "${SFTP_KEY:-}" ]]; then
        ssh_opts="$ssh_opts -i $SFTP_KEY"
      fi
      # shellcheck disable=SC2086
      ssh $ssh_opts "${SFTP_USER}@${SFTP_HOST}" "mkdir -p '${SFTP_PATH}/${backup_id}'" 2>/dev/null
      # shellcheck disable=SC2086
      scp -r $ssh_opts "$src/"* "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/${backup_id}/" 2>&1 || \
        { log_error "SFTP upload failed"; return 1; }
      ;;

    r2)
      log_step "Uploading to Cloudflare R2: ${S3_BUCKET}/${backup_id}/"
      if $DRY_RUN; then
        log_info "[dry-run] Would upload to r2://${S3_BUCKET}/${backup_id}/"
        return
      fi
      # R2 uses S3-compatible API
      if command -v aws >/dev/null 2>&1; then
        AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
        AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
        aws s3 cp --recursive "$src/" "s3://${S3_BUCKET}/${backup_id}/" \
          --endpoint-url "${S3_ENDPOINT}" 2>&1 || { log_error "R2 upload failed"; return 1; }
      else
        log_error "awscli not found for R2 uploads."
        return 1
      fi
      ;;

    *)
      log_error "Unknown BACKUP_TARGET: $BACKUP_TARGET"
      log_error "Supported: local, s3, b2, sftp, r2"
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# List backups
# ---------------------------------------------------------------------------
list_backups() {
  log_info "Available backups in $BACKUP_DIR:"
  echo ""
  printf "%-22s %-10s %-8s %s\n" "BACKUP ID" "SIZE" "FILES" "DATE"
  printf "%-22s %-10s %-8s %s\n" "─────────" "────" "─────" "────"

  if [[ -d "$BACKUP_DIR" ]]; then
    for dir in "$BACKUP_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      local bid
      bid=$(basename "$dir")
      local size
      size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      local count
      count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
      local date
      date=$(stat -c '%y' "$dir" 2>/dev/null | cut -d. -f1 || stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$dir" 2>/dev/null || echo "unknown")
      printf "%-22s %-10s %-8s %s\n" "$bid" "$size" "$count" "$date"
    done
  fi

  # Also list remote backups if configured
  if [[ "$BACKUP_TARGET" == "s3" || "$BACKUP_TARGET" == "r2" ]] && command -v aws >/dev/null 2>&1; then
    echo ""
    log_info "Remote backups (${BACKUP_TARGET}):"
    AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY:-}" \
    AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY:-}" \
    aws s3 ls "s3://${S3_BUCKET:-}/" --endpoint-url "${S3_ENDPOINT:-}" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Verify backup
# ---------------------------------------------------------------------------
verify_backup() {
  local target="${1:-latest}"
  local backup_path

  if [[ "$target" == "latest" ]]; then
    backup_path=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' 2>/dev/null | sort -r | head -1)
  else
    backup_path="$BACKUP_DIR/$target"
  fi

  if [[ -z "$backup_path" || ! -d "$backup_path" ]]; then
    log_error "Backup not found: $target"
    exit 1
  fi

  local bid
  bid=$(basename "$backup_path")
  log_info "Verifying backup: $bid"
  echo ""

  local total=0
  local passed=0
  local failed=0

  for f in "$backup_path"/*; do
    [[ -f "$f" ]] || continue
    total=$((total + 1))
    local fname
    fname=$(basename "$f")

    case "$fname" in
      *.tar.gz)
        if tar tzf "$f" >/dev/null 2>&1; then
          echo -e "  ✅ $fname — valid tar.gz"
          passed=$((passed + 1))
        else
          echo -e "  ❌ $fname — CORRUPTED"
          failed=$((failed + 1))
        fi
        ;;
      *.sql.gz)
        if gzip -t "$f" 2>/dev/null; then
          echo -e "  ✅ $fname — valid gzip"
          passed=$((passed + 1))
        else
          echo -e "  ❌ $fname — CORRUPTED"
          failed=$((failed + 1))
        fi
        ;;
      *.rdb)
        if [[ -s "$f" ]]; then
          echo -e "  ✅ $fname — non-empty ($(du -sh "$f" | cut -f1))"
          passed=$((passed + 1))
        else
          echo -e "  ❌ $fname — EMPTY"
          failed=$((failed + 1))
        fi
        ;;
      *.enc)
        if [[ -s "$f" ]]; then
          echo -e "  ✅ $fname — encrypted file present"
          passed=$((passed + 1))
        else
          echo -e "  ❌ $fname — EMPTY"
          failed=$((failed + 1))
        fi
        ;;
      manifest.json)
        if jq . "$f" >/dev/null 2>&1; then
          echo -e "  ✅ $fname — valid JSON"
          passed=$((passed + 1))
        else
          echo -e "  ❌ $fname — invalid JSON"
          failed=$((failed + 1))
        fi
        ;;
      *)
        if [[ -s "$f" ]]; then
          echo -e "  ✅ $fname — present"
          passed=$((passed + 1))
        else
          echo -e "  ⚠️  $fname — empty"
          failed=$((failed + 1))
        fi
        ;;
    esac
  done

  echo ""
  if [[ $failed -eq 0 ]]; then
    log_info "Verification PASSED: $passed/$total files OK"
  else
    log_error "Verification FAILED: $failed/$total files corrupted"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
restore_backup() {
  local backup_id="$1"
  local restore_path="$BACKUP_DIR/$backup_id"

  if [[ ! -d "$restore_path" ]]; then
    # Try downloading from remote
    if [[ "$BACKUP_TARGET" != "local" ]]; then
      log_info "Backup not found locally. Downloading from $BACKUP_TARGET..."
      mkdir -p "$restore_path"
      case "$BACKUP_TARGET" in
        s3|r2)
          AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
          AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
          aws s3 cp --recursive "s3://${S3_BUCKET}/${backup_id}/" "$restore_path/" \
            --endpoint-url "${S3_ENDPOINT}" 2>&1
          ;;
        sftp)
          local ssh_opts="-o StrictHostKeyChecking=accept-new"
          [[ -n "${SFTP_KEY:-}" ]] && ssh_opts="$ssh_opts -i $SFTP_KEY"
          # shellcheck disable=SC2086
          scp -r $ssh_opts "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/${backup_id}/*" "$restore_path/" 2>&1
          ;;
        *)
          log_error "Cannot download from $BACKUP_TARGET"
          exit 1
          ;;
      esac
    else
      log_error "Backup not found: $restore_path"
      log_error "Available backups:"
      list_backups
      exit 1
    fi
  fi

  log_warn "⚠️  RESTORE will overwrite current data!"
  log_warn "Backup: $backup_id"
  echo ""
  read -rp "Type 'RESTORE' to confirm: " confirm
  if [[ "$confirm" != "RESTORE" ]]; then
    log_info "Restore cancelled."
    exit 0
  fi

  # Decrypt if needed
  if ls "$restore_path"/*.enc >/dev/null 2>&1; then
    if [[ -z "$ENCRYPTION_KEY" ]]; then
      log_error "Encrypted backup — set BACKUP_ENCRYPTION_KEY"
      exit 1
    fi
    for f in "$restore_path"/*.enc; do
      decrypt_file "$f"
    done
  fi

  # Restore configs
  if [[ -f "$restore_path/configs.tar.gz" ]]; then
    log_step "Restoring configs..."
    tar xzf "$restore_path/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || \
      log_warn "Config restore had warnings"
  fi

  # Restore Docker volumes
  for f in "$restore_path"/vol_*.tar.gz; do
    [[ -f "$f" ]] || continue
    local vol_name
    vol_name=$(basename "$f" .tar.gz)
    vol_name="${vol_name#vol_}"
    log_step "Restoring volume: $vol_name"
    docker volume create "$vol_name" 2>/dev/null || true
    docker run --rm \
      -v "${vol_name}:/data" \
      -v "$restore_path:/backup:ro" \
      alpine:3.19 \
      sh -c "cd /data && tar xzf /backup/$(basename "$f")" 2>/dev/null || \
      log_warn "Failed to restore volume: $vol_name"
  done

  # Restore PostgreSQL
  if [[ -f "$restore_path/postgresql_all.sql.gz" ]]; then
    log_step "Restoring PostgreSQL..."
    if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
      local pg_user
      pg_user=$(docker exec homelab-postgres printenv POSTGRES_USER 2>/dev/null || echo "postgres")
      gunzip -c "$restore_path/postgresql_all.sql.gz" | \
        docker exec -i homelab-postgres psql -U "$pg_user" 2>/dev/null || \
        log_warn "PostgreSQL restore had warnings"
    else
      log_warn "PostgreSQL container not running — skip DB restore"
    fi
  fi

  # Restore MariaDB
  if [[ -f "$restore_path/mariadb_all.sql.gz" ]]; then
    log_step "Restoring MariaDB..."
    if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
      local maria_pass
      maria_pass=$(docker exec homelab-mariadb printenv MARIADB_ROOT_PASSWORD 2>/dev/null || echo "")
      gunzip -c "$restore_path/mariadb_all.sql.gz" | \
        docker exec -i homelab-mariadb mariadb -u root -p"$maria_pass" 2>/dev/null || \
        log_warn "MariaDB restore had warnings"
    else
      log_warn "MariaDB container not running — skip DB restore"
    fi
  fi

  # Restore Redis
  if [[ -f "$restore_path/redis_dump.rdb" ]]; then
    log_step "Restoring Redis..."
    if docker ps --format '{{.Names}}' | grep -q 'homelab-redis'; then
      docker cp "$restore_path/redis_dump.rdb" homelab-redis:/data/dump.rdb 2>/dev/null
      docker restart homelab-redis 2>/dev/null || \
        log_warn "Redis restore/restart failed"
    else
      log_warn "Redis container not running — skip Redis restore"
    fi
  fi

  log_info "Restore complete from backup: $backup_id"
  notify "🔄 Restore Complete" "Restored from backup $backup_id"
}

# ---------------------------------------------------------------------------
# Cleanup old backups
# ---------------------------------------------------------------------------
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
generate_manifest() {
  local dest="$1"

  if $DRY_RUN; then return; fi

  local total_size
  total_size=$(du -sh "$dest" 2>/dev/null | cut -f1)
  local file_count
  file_count=$(find "$dest" -type f 2>/dev/null | wc -l | tr -d ' ')

  # Generate JSON manifest
  local manifest="$dest/manifest.json"
  {
    echo "{"
    echo "  \"backup_id\": \"$TIMESTAMP\","
    echo "  \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"target\": \"$BACKUP_TARGET\","
    echo "  \"encrypted\": $DO_ENCRYPT,"
    echo "  \"total_size\": \"$total_size\","
    echo "  \"file_count\": $file_count,"
    echo "  \"retention_days\": $RETENTION_DAYS,"
    echo "  \"files\": ["
    local first=true
    for f in "$dest"/*; do
      [[ -f "$f" ]] || continue
      local fname
      fname=$(basename "$f")
      [[ "$fname" == "manifest.json" ]] && continue
      local fsize
      fsize=$(du -sh "$f" 2>/dev/null | cut -f1)
      local fsha
      fsha=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1 || echo "")
      if $first; then first=false; else echo ","; fi
      printf '    {"name": "%s", "size": "%s", "sha256": "%s"}' "$fname" "$fsize" "$fsha"
    done
    echo ""
    echo "  ]"
    echo "}"
  } > "$manifest"
}

# ---------------------------------------------------------------------------
# Run backup for a specific stack
# ---------------------------------------------------------------------------
backup_stack() {
  local stack="$1"
  local dest="$BACKUP_PATH"

  log_step "Backing up stack: $stack"

  case "$stack" in
    databases)
      backup_databases "$dest"
      # Also backup database volumes
      while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        backup_volume "$vol" "$dest"
      done < <(get_stack_volumes "databases")
      ;;
    all)
      # Databases first (hot backup)
      backup_databases "$dest"
      # All configs
      backup_configs "$dest"
      # All Docker volumes
      local vols
      vols=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -v '^[a-f0-9]\{64\}$' || true)
      while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        backup_volume "$vol" "$dest"
      done <<< "$vols"
      ;;
    *)
      # Generic stack backup
      backup_configs "$dest"
      while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        backup_volume "$vol" "$dest"
      done < <(get_stack_volumes "$stack")
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
STACK_TARGET=""
RESTORE_ID=""
DO_LIST=false
DO_VERIFY=false
VERIFY_TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   shift; STACK_TARGET="${1:-all}" ;;
    --dry-run)  DRY_RUN=true ;;
    --encrypt)  DO_ENCRYPT=true ;;
    --restore)  shift; RESTORE_ID="${1:-}" ;;
    --list)     DO_LIST=true ;;
    --verify)
      DO_VERIFY=true
      if [[ "${2:-}" =~ ^[0-9]{8} ]]; then
        shift; VERIFY_TARGET="$1"
      fi
      ;;
    --help|-h)  usage ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# Dispatch command
if $DO_LIST; then
  list_backups
  exit 0
fi

if $DO_VERIFY; then
  verify_backup "${VERIFY_TARGET:-latest}"
  exit 0
fi

if [[ -n "$RESTORE_ID" ]]; then
  restore_backup "$RESTORE_ID"
  exit 0
fi

if [[ -z "$STACK_TARGET" ]]; then
  log_error "No --target specified"
  usage
fi

# Encryption check
if $DO_ENCRYPT && [[ -z "$ENCRYPTION_KEY" ]]; then
  log_error "Encryption requested but BACKUP_ENCRYPTION_KEY not set"
  exit 1
fi

# Run backup
log_info "═══════════════════════════════════════════"
log_info "HomeLab Backup — $(date)"
log_info "Target: $STACK_TARGET | Backend: $BACKUP_TARGET"
log_info "Encrypt: $DO_ENCRYPT | Dry-run: $DRY_RUN"
log_info "═══════════════════════════════════════════"

if ! $DRY_RUN; then
  mkdir -p "$BACKUP_PATH"
fi

# Track timing
START_TIME=$(date +%s)
BACKUP_STATUS="success"

{
  backup_stack "$STACK_TARGET"
  generate_manifest "$BACKUP_PATH"
  upload_backup "$BACKUP_PATH"
  cleanup_old
} || BACKUP_STATUS="failed"

END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))

if ! $DRY_RUN; then
  local_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1 || echo "N/A")
  log_info "═══════════════════════════════════════════"
  log_info "Backup complete: $TIMESTAMP"
  log_info "Size: $local_size | Duration: ${DURATION}s"
  log_info "Backend: $BACKUP_TARGET | Encrypted: $DO_ENCRYPT"
  log_info "═══════════════════════════════════════════"

  if [[ "$BACKUP_STATUS" == "success" ]]; then
    notify "✅ Backup Complete" \
      "Backup $TIMESTAMP finished in ${DURATION}s ($local_size). Target: $STACK_TARGET, Backend: $BACKUP_TARGET" \
      "default"
  else
    notify "❌ Backup Failed" \
      "Backup $TIMESTAMP failed after ${DURATION}s. Target: $STACK_TARGET, Backend: $BACKUP_TARGET" \
      "high"
  fi
else
  log_info "Dry run complete — no data was written."
fi
