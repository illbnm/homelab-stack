#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/stacks/backup/.env"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/backup_${TIMESTAMP}.log"
DRY_RUN=false
TARGET="all"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GREEN}✓ $*${NC}"; }
warn() { log "${YELLOW}⚠ $*${NC}"; }
err()  { log "${RED}✗ $*${NC}"; }

load_env() {
    [[ -f "$ENV_FILE" ]] || { err "No .env found at $ENV_FILE"; exit 1; }
    set -a; source "$ENV_FILE"; set +a
}

notify() {
    local title="$1" msg="$2"
    if [[ -n "${NTFY_URL:-}" && -n "${NTFY_TOPIC:-}" ]]; then
        curl -sf -H "Priority: ${NTFY_PRIORITY:-default}" \
            -d "$msg" "${NTFY_URL}/${NTFY_TOPIC}" &>/dev/null || true
    fi
}

backup_volumes() {
    local stack="$1"
    local stack_dir="${PROJECT_DIR}/stacks/${stack}"
    local compose_file=""

    if [[ -f "${stack_dir}/docker-compose.yml" ]]; then
        compose_file="${stack_dir}/docker-compose.yml"
    elif [[ -f "${stack_dir}/compose.yml" ]]; then
        compose_file="${stack_dir}/compose.yml"
    else
        warn "No compose file found for stack: $stack"
        return
    fi

    local dest="${BACKUP_DIR}/${stack}/${TIMESTAMP}"
    mkdir -p "$dest"

    # Get named volumes for this stack
    local volumes
    volumes=$(docker compose -f "$compose_file" config --volumes 2>/dev/null | grep -v '^\s*#' | grep -v '^$' || true)

    for vol in $volumes; do
        local vol_path
        vol_path=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null) || continue
        if $DRY_RUN; then
            log "[DRY-RUN] Would backup volume: $vol → $dest/${vol}.tar.gz"
        else
            log "Backing up volume: $vol"
            tar czf "${dest}/${vol}.tar.gz" -C "$(dirname "$vol_path")" "$(basename "$vol_path")" 2>/dev/null || warn "Failed to backup $vol"
            ok "Backed up $vol"
        fi
    done
}

backup_databases() {
    local dest="${BACKUP_DIR}/databases/${TIMESTAMP}"
    mkdir -p "$dest"

    # PostgreSQL databases
    for container in $(docker ps --filter "ancestor=postgres" --format '{{.Names}}' 2>/dev/null); do
        if $DRY_RUN; then
            log "[DRY-RUN] Would dump PostgreSQL from: $container"
        else
            docker exec "$container" pg_dumpall -U "${POSTGRES_USER:-postgres}" 2>/dev/null | \
                gzip > "${dest}/${container}_pgdump.sql.gz" && ok "Dumped $container" || warn "Failed to dump $container"
        fi
    done

    # MySQL/MariaDB
    for container in $(docker ps --filter "name=mysql\|mariadb" --format '{{.Names}}' 2>/dev/null); do
        if $DRY_RUN; then
            log "[DRY-RUN] Would dump MySQL from: $container"
        else
            docker exec "$container" mysqldump -u root --all-databases 2>/dev/null | \
                gzip > "${dest}/${container}_mysqldump.sql.gz" && ok "Dumped $container" || warn "Failed to dump $container"
        fi
    done
}

upload_target() {
    local src="$1"
    if $DRY_RUN; then
        log "[DRY-RUN] Would upload to ${BACKUP_TARGET:-local}"
        return
    fi

    case "${BACKUP_TARGET:-local}" in
        local)
            mkdir -p "${BACKUP_LOCAL_PATH:-/mnt/backup}"
            rsync -az "$src/" "${BACKUP_LOCAL_PATH:-/mnt/backup}/" && ok "Uploaded to local" || err "Local upload failed"
            ;;
        s3)
            [[ -n "${S3_ENDPOINT:-}" ]] || { err "S3_ENDPOINT not set"; return 1; }
            docker run --rm -v "$src":/data -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
                amazon/aws-cli s3 sync /data/ "s3://${S3_BUCKET}/$(date +%Y%m)/" --endpoint-url="$S3_ENDPOINT" && ok "Uploaded to S3" || err "S3 upload failed"
            ;;
        sftp)
            [[ -n "${SFTP_HOST:-}" ]] || { err "SFTP_HOST not set"; return 1; }
            rsync -az -e "ssh -p ${SFTP_PORT:-22}" "$src/" "${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}/" && ok "Uploaded via SFTP" || err "SFTP upload failed"
            ;;
        *)
            err "Unknown BACKUP_TARGET: ${BACKUP_TARGET}"
            ;;
    esac
}

list_backups() {
    [[ -d "$BACKUP_DIR" ]] || { log "No backups found"; return; }
    log "=== Available Backups ==="
    find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql.gz" | sort
}

verify_backup() {
    log "=== Verifying Backups ==="
    local failed=0
    for f in $(find "$BACKUP_DIR" -name "*.tar.gz"); do
        tar tzf "$f" &>/dev/null && ok "$f" || { err "$f CORRUPT"; ((failed++)); }
    done
    for f in $(find "$BACKUP_DIR" -name "*.sql.gz"); do
        gzip -t "$f" && ok "$f" || { err "$f CORRUPT"; ((failed++)); }
    done
    if [[ $failed -eq 0 ]]; then
        ok "All backups verified"
        notify "Backup Verify" "All backups passed verification ✓"
    else
        err "$failed backup(s) corrupted"
        notify "Backup Verify" "FAILED: $failed backup(s) corrupted ✗"
    fi
}

usage() {
    cat <<EOF
Usage: backup.sh --target <stack|all> [options]

Options:
  --target <name>   Backup specific stack or 'all'
  --dry-run         Show what would be backed up
  --list            List all backups
  --verify          Verify backup integrity
  --help            Show this help
EOF
}

main() {
    load_env

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target) TARGET="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --list) list_backups; exit 0 ;;
            --verify) verify_backup; exit 0 ;;
            --help) usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    log "=== Backup Started (target: $TARGET, dry-run: $DRY_RUN) ==="

    if [[ "$TARGET" == "all" ]]; then
        for stack in "${PROJECT_DIR}"/stacks/*/; do
            backup_volumes "$(basename "$stack")"
        done
    else
        backup_volumes "$TARGET"
    fi

    backup_databases
    upload_target "$BACKUP_DIR"

    log "=== Backup Completed ==="
    notify "Backup" "Backup completed for target: $TARGET ✓"
}

main "$@"
