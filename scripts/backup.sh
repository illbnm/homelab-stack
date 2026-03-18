#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script
# - backup by stack or all
# - dry-run, list, verify, restore
# - upload target: local | s3 | b2 | sftp
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ROOT_ENV_FILE="$BASE_DIR/.env"
CONFIG_ENV_FILE="$BASE_DIR/config/.env"
if [[ -f "$ROOT_ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_ENV_FILE"
elif [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_ENV_FILE"
fi

BACKUP_DIR="${BACKUP_DIR:-$BASE_DIR/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
UPLOAD_TARGET="${BACKUP_TARGET:-local}"
STACKS_DIR="$BASE_DIR/stacks"

BACKUP_NOTIFY_URL="${BACKUP_NOTIFY_URL:-}"
BACKUP_NOTIFY_TOPIC="${BACKUP_NOTIFY_TOPIC:-homelab-backup}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --target <stack|all> [options]

Options:
  --target all|<stack>  Backup all volumes or a single stack scope
  --dry-run             Show what would be backed up, no changes made
  --restore <backup_id> Restore data from backup id (timestamp directory)
  --list                List available backups
  --verify [backup_id]  Verify backup integrity (latest if omitted)
  --help                Show this help

Environment:
  BACKUP_TARGET=local|s3|b2|sftp

  local:
    Keeps backups under BACKUP_DIR only.

  s3:
    BACKUP_S3_BUCKET, BACKUP_S3_PREFIX, BACKUP_S3_REGION
    BACKUP_S3_ACCESS_KEY_ID, BACKUP_S3_SECRET_ACCESS_KEY
    BACKUP_S3_ENDPOINT (optional, use for MinIO or Cloudflare R2)

  b2:
    BACKUP_B2_BUCKET, BACKUP_B2_PREFIX, BACKUP_B2_REGION
    BACKUP_B2_ACCESS_KEY_ID, BACKUP_B2_SECRET_ACCESS_KEY
    BACKUP_B2_ENDPOINT (optional)

  sftp:
    BACKUP_SFTP_USER, BACKUP_SFTP_HOST, BACKUP_SFTP_PATH
    BACKUP_SFTP_PORT (default 22), BACKUP_SFTP_IDENTITY_FILE (optional)
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    exit 1
  fi
}

docker_ready() {
  docker info >/dev/null 2>&1
}

checksum_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

send_notification() {
  local status="$1"
  local message="$2"
  [[ -z "$BACKUP_NOTIFY_URL" ]] && return 0

  curl -fsS -X POST \
    -H "Title: HomeLab Backup $status" \
    -H "Tags: floppy_disk" \
    -H "X-Topic: $BACKUP_NOTIFY_TOPIC" \
    -d "$message" \
    "$BACKUP_NOTIFY_URL" >/dev/null 2>&1 || true
}

get_compose_file() {
  local stack="$1"
  local dir="$STACKS_DIR/$stack"
  if [[ -f "$dir/docker-compose.local.yml" ]]; then
    echo "$dir/docker-compose.local.yml"
  elif [[ -f "$dir/docker-compose.yml" ]]; then
    echo "$dir/docker-compose.yml"
  else
    return 1
  fi
}

list_backups() {
  mkdir -p "$BACKUP_DIR"
  local count=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    count=$((count + 1))
    local size
    size=$(du -sh "$BACKUP_DIR/$entry" 2>/dev/null | awk '{print $1}')
    printf '%s  %s\n' "$entry" "${size:-unknown}"
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' -print | xargs -I{} basename {} | sort)

  if [[ "$count" -eq 0 ]]; then
    log_info "No backups found in $BACKUP_DIR"
  fi
}

get_stack_volumes() {
  local stack="$1"
  local compose_file
  compose_file=$(get_compose_file "$stack") || {
    log_error "Unknown stack: $stack"
    return 1
  }

  {
    docker compose -f "$compose_file" ps -q 2>/dev/null \
      | while IFS= read -r cid; do
          [[ -z "$cid" ]] && continue
          docker inspect "$cid" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' 2>/dev/null
        done

    docker compose -f "$compose_file" config --volumes 2>/dev/null \
      | while IFS= read -r raw_name; do
          [[ -z "$raw_name" ]] && continue
          if docker volume inspect "$raw_name" >/dev/null 2>&1; then
            echo "$raw_name"
          fi
          docker volume ls --format '{{.Name}}' 2>/dev/null | grep "_${raw_name}$" || true
        done
  } | awk 'NF' | sort -u
}

get_all_volumes() {
  docker volume ls --format '{{.Name}}' 2>/dev/null | grep -v '^[a-f0-9]\{64\}$' || true
}

backup_configs() {
  local backup_path="$1"
  log_info "Backing up repository configs"
  tar czf "$backup_path/configs.tar.gz" \
    -C "$BASE_DIR" \
    config scripts docs stacks .env.example >/dev/null 2>&1 || true
}

backup_databases() {
  local backup_path="$1"
  log_info "Backing up databases"
  mkdir -p "$backup_path/databases"

  local pg_container
  pg_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-postgres|postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    local pg_user pg_pass
    pg_user=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^POSTGRES_USER=' | cut -d= -f2- | head -1 || true)
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^POSTGRES_PASSWORD=' | cut -d= -f2- | head -1 || true)
    pg_user="${pg_user:-postgres}"
    docker exec "$pg_container" sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U '$pg_user'" > "$backup_path/databases/postgresql_all.sql" \
      || log_warn "PostgreSQL backup failed"
  else
    log_warn "PostgreSQL container not found, skipping"
  fi

  local mysql_container
  mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-mariadb|mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^MARIADB_ROOT_PASSWORD=|^MYSQL_ROOT_PASSWORD=' | cut -d= -f2- | head -1 || true)
    docker exec "$mysql_container" sh -c "mariadb-dump --all-databases -u root -p'$mysql_pass'" > "$backup_path/databases/mysql_all.sql" \
      || log_warn "MariaDB backup failed"
  else
    log_warn "MariaDB/MySQL container not found, skipping"
  fi

  local redis_container
  redis_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-redis|redis' | head -1 || true)
  if [[ -n "$redis_container" ]]; then
    local redis_pass
    redis_pass=$(docker inspect "$redis_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^REDIS_PASSWORD=' | cut -d= -f2- | head -1 || true)
    if [[ -n "$redis_pass" ]]; then
      docker exec "$redis_container" redis-cli -a "$redis_pass" --no-auth-warning BGSAVE >/dev/null 2>&1 || true
    else
      docker exec "$redis_container" redis-cli BGSAVE >/dev/null 2>&1 || true
    fi
    sleep 2
    docker cp "$redis_container:/data/dump.rdb" "$backup_path/databases/redis_dump.rdb" || log_warn "Redis backup failed"
  else
    log_warn "Redis container not found, skipping"
  fi
}

backup_volumes() {
  local backup_path="$1"
  local backup_scope="$2"
  local volume_list_file="$backup_path/volumes.list"

  mkdir -p "$backup_path/volumes"
  : > "$volume_list_file"

  local volumes
  if [[ "$backup_scope" == "all" ]]; then
    volumes=$(get_all_volumes)
  else
    volumes=$(get_stack_volumes "$backup_scope")
  fi

  if [[ -z "$volumes" ]]; then
    log_warn "No volumes found for scope: $backup_scope"
    return 0
  fi

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "Backing up volume: $vol"
    echo "$vol" >> "$volume_list_file"
    docker run --rm \
      -v "$vol:/data:ro" \
      -v "$backup_path/volumes:/backup" \
      alpine:3.20 \
      sh -c "tar czf /backup/${vol}.tar.gz -C /data ." >/dev/null 2>&1 \
      || log_warn "Failed to back up volume: $vol"
  done <<< "$volumes"
}

write_manifest() {
  local backup_path="$1"
  local manifest="$backup_path/manifest.sha256"
  : > "$manifest"

  while IFS= read -r f; do
    local rel
    rel="${f#"$backup_path/"}"
    printf '%s  %s\n' "$(checksum_file "$f")" "$rel" >> "$manifest"
  done < <(find "$backup_path" -type f ! -name 'manifest.sha256' | sort)
}

verify_manifest() {
  local backup_path="$1"
  local manifest="$backup_path/manifest.sha256"

  [[ -f "$manifest" ]] || {
    log_error "Missing manifest: $manifest"
    return 1
  }

  local failed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local expected rel actual
    expected=$(echo "$line" | awk '{print $1}')
    rel=$(echo "$line" | awk '{print $2}')
    if [[ ! -f "$backup_path/$rel" ]]; then
      log_error "Missing file: $rel"
      failed=1
      continue
    fi
    actual=$(checksum_file "$backup_path/$rel")
    if [[ "$expected" != "$actual" ]]; then
      log_error "Checksum mismatch: $rel"
      failed=1
    fi
  done < "$manifest"

  if [[ "$failed" -eq 0 ]]; then
    log_info "Backup integrity verified: $backup_path"
  fi
  return "$failed"
}

upload_backup() {
  local backup_path="$1"
  local backup_id="$2"

  if [[ "$UPLOAD_TARGET" == "local" ]]; then
    log_info "Upload target is local, skipping remote upload"
    return 0
  fi

  local archive="$BACKUP_DIR/${backup_id}.tar.gz"
  tar czf "$archive" -C "$BACKUP_DIR" "$backup_id"

  case "$UPLOAD_TARGET" in
    s3)
      require_cmd aws
      : "${BACKUP_S3_BUCKET:?BACKUP_S3_BUCKET is required for s3 target}"
      : "${BACKUP_S3_ACCESS_KEY_ID:?BACKUP_S3_ACCESS_KEY_ID is required}"
      : "${BACKUP_S3_SECRET_ACCESS_KEY:?BACKUP_S3_SECRET_ACCESS_KEY is required}"

      AWS_ACCESS_KEY_ID="$BACKUP_S3_ACCESS_KEY_ID" \
      AWS_SECRET_ACCESS_KEY="$BACKUP_S3_SECRET_ACCESS_KEY" \
      AWS_DEFAULT_REGION="${BACKUP_S3_REGION:-auto}" \
      aws ${BACKUP_S3_ENDPOINT:+--endpoint-url "$BACKUP_S3_ENDPOINT"} \
        s3 cp "$archive" "s3://${BACKUP_S3_BUCKET}/${BACKUP_S3_PREFIX:-homelab}/${backup_id}.tar.gz"
      ;;
    b2)
      require_cmd aws
      : "${BACKUP_B2_BUCKET:?BACKUP_B2_BUCKET is required for b2 target}"
      : "${BACKUP_B2_ACCESS_KEY_ID:?BACKUP_B2_ACCESS_KEY_ID is required}"
      : "${BACKUP_B2_SECRET_ACCESS_KEY:?BACKUP_B2_SECRET_ACCESS_KEY is required}"

      AWS_ACCESS_KEY_ID="$BACKUP_B2_ACCESS_KEY_ID" \
      AWS_SECRET_ACCESS_KEY="$BACKUP_B2_SECRET_ACCESS_KEY" \
      AWS_DEFAULT_REGION="${BACKUP_B2_REGION:-us-west-004}" \
      aws ${BACKUP_B2_ENDPOINT:+--endpoint-url "$BACKUP_B2_ENDPOINT"} \
        s3 cp "$archive" "s3://${BACKUP_B2_BUCKET}/${BACKUP_B2_PREFIX:-homelab}/${backup_id}.tar.gz"
      ;;
    sftp)
      require_cmd scp
      : "${BACKUP_SFTP_USER:?BACKUP_SFTP_USER is required for sftp target}"
      : "${BACKUP_SFTP_HOST:?BACKUP_SFTP_HOST is required for sftp target}"
      : "${BACKUP_SFTP_PATH:?BACKUP_SFTP_PATH is required for sftp target}"

      scp -P "${BACKUP_SFTP_PORT:-22}" \
        ${BACKUP_SFTP_IDENTITY_FILE:+-i "$BACKUP_SFTP_IDENTITY_FILE"} \
        "$archive" "${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH%/}/"
      ;;
    *)
      log_error "Unsupported BACKUP_TARGET: $UPLOAD_TARGET"
      return 1
      ;;
  esac

  log_info "Uploaded backup archive using target: $UPLOAD_TARGET"
}

cleanup_old() {
  log_info "Removing backups older than ${RETENTION_DAYS} days"
  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -name '20*_*' -exec rm -rf {} + 2>/dev/null || true
}

restore_backup() {
  local backup_id="$1"
  local restore_scope="$2"
  local backup_path="$BACKUP_DIR/$backup_id"

  [[ -d "$backup_path" ]] || {
    log_error "Backup not found: $backup_id"
    exit 1
  }

  verify_manifest "$backup_path"

  local restore_volumes
  if [[ "$restore_scope" == "all" ]]; then
    restore_volumes=$(cat "$backup_path/volumes.list" 2>/dev/null || true)
  else
    restore_volumes=$(get_stack_volumes "$restore_scope")
  fi

  if [[ -n "$restore_volumes" ]]; then
    while IFS= read -r vol; do
      [[ -z "$vol" ]] && continue
      [[ -f "$backup_path/volumes/${vol}.tar.gz" ]] || continue

      log_info "Restoring volume: $vol"
      docker volume create "$vol" >/dev/null
      docker run --rm \
        -v "$vol:/data" \
        -v "$backup_path/volumes:/backup:ro" \
        alpine:3.20 \
        sh -c "rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null || true; tar xzf /backup/${vol}.tar.gz -C /data"
    done <<< "$restore_volumes"
  fi

  if [[ -f "$backup_path/databases/postgresql_all.sql" ]]; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-postgres|postgres|postgresql' | head -1 || true)
    if [[ -n "$pg_container" ]]; then
      local pg_user pg_pass
      pg_user=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^POSTGRES_USER=' | cut -d= -f2- | head -1 || true)
      pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^POSTGRES_PASSWORD=' | cut -d= -f2- | head -1 || true)
      pg_user="${pg_user:-postgres}"
      log_info "Restoring PostgreSQL dump"
      docker exec -i "$pg_container" sh -c "PGPASSWORD='$pg_pass' psql -U '$pg_user' -d postgres" < "$backup_path/databases/postgresql_all.sql" || log_warn "PostgreSQL restore failed"
    fi
  fi

  if [[ -f "$backup_path/databases/mysql_all.sql" ]]; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-mariadb|mariadb|mysql' | head -1 || true)
    if [[ -n "$mysql_container" ]]; then
      local mysql_pass
      mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^MARIADB_ROOT_PASSWORD=|^MYSQL_ROOT_PASSWORD=' | cut -d= -f2- | head -1 || true)
      log_info "Restoring MariaDB/MySQL dump"
      docker exec -i "$mysql_container" sh -c "mariadb -u root -p'$mysql_pass'" < "$backup_path/databases/mysql_all.sql" || log_warn "MySQL restore failed"
    fi
  fi

  if [[ -f "$backup_path/databases/redis_dump.rdb" ]]; then
    log_warn "Redis restore requires service restart. File is available at: $backup_path/databases/redis_dump.rdb"
  fi

  log_info "Restore completed for backup id: $backup_id"
}

run_backup() {
  local backup_scope="$1"
  local dry_run="$2"

  local backup_id
  backup_id=$(date +%Y%m%d_%H%M%S)
  local backup_path="$BACKUP_DIR/$backup_id"

  local volumes
  if docker_ready; then
    if [[ "$backup_scope" == "all" ]]; then
      volumes=$(get_all_volumes)
    else
      volumes=$(get_stack_volumes "$backup_scope")
    fi
  else
    volumes=""
    log_warn "Docker daemon not available; volume discovery skipped"
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo "Backup scope: $backup_scope"
    echo "Upload target: $UPLOAD_TARGET"
    echo "Backup directory: $backup_path"
    echo "Volumes:"
    if [[ -n "$volumes" ]]; then
      echo "$volumes"
    else
      echo "  (none)"
    fi
    echo "Databases: PostgreSQL, MariaDB/MySQL, Redis (if containers are running)"
    return 0
  fi

  mkdir -p "$backup_path"

  log_info "Starting backup id: $backup_id"
  log_info "Scope: $backup_scope"
  log_info "Upload target: $UPLOAD_TARGET"

  backup_configs "$backup_path"
  backup_volumes "$backup_path" "$backup_scope"
  backup_databases "$backup_path"
  write_manifest "$backup_path"
  verify_manifest "$backup_path"
  upload_backup "$backup_path" "$backup_id"
  cleanup_old

  local size
  size=$(du -sh "$backup_path" 2>/dev/null | awk '{print $1}')
  log_info "Backup completed: $backup_path (${size:-unknown})"
  send_notification "success" "Backup succeeded: ${backup_id} (${size:-unknown})"
}

main() {
  local backup_scope=""
  local dry_run="false"
  local restore_id=""
  local do_list="false"
  local do_verify="false"
  local verify_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        backup_scope="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --restore)
        restore_id="${2:-}"
        shift 2
        ;;
      --list)
        do_list="true"
        shift
        ;;
      --verify)
        do_verify="true"
        if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
          verify_id="$2"
          shift 2
        else
          shift
        fi
        ;;
      --help|-h)
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

  mkdir -p "$BACKUP_DIR"

  if [[ "$do_list" == "true" ]]; then
    list_backups
    exit 0
  fi

  if [[ "$do_verify" == "true" ]]; then
    if [[ -z "$verify_id" ]]; then
      verify_id=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' -print | xargs -I{} basename {} | sort | tail -1)
      [[ -n "$verify_id" ]] || { log_error "No backups found to verify"; exit 1; }
    fi
    verify_manifest "$BACKUP_DIR/$verify_id"
    exit 0
  fi

  if [[ -n "$restore_id" ]]; then
    require_cmd docker
    [[ -n "$backup_scope" ]] || backup_scope="all"
    restore_backup "$restore_id" "$backup_scope"
    send_notification "restore" "Restore finished from backup id: $restore_id"
    exit 0
  fi

  [[ -n "$backup_scope" ]] || {
    log_error "--target is required for backup mode"
    usage
    exit 1
  }

  require_cmd docker
  require_cmd tar

  run_backup "$backup_scope" "$dry_run" || {
    send_notification "failed" "Backup failed for scope: $backup_scope"
    exit 1
  }
}

main "$@"
