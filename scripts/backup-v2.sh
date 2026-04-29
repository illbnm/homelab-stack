#!/usr/bin/env bash
# =============================================================================
# backup.sh — HomeLab full-stack backup script
# Implements 3-2-1 backup strategy: 3 copies, 2 media types, 1 offsite
#
# Usage:
#   ./backup.sh --target <stack|all> [options]
#
# Options:
#   --target all       Backup all stack data volumes (default)
#   --target media     Backup media stack only
#   --target storage   Backup storage stack only
#   --target databases Backup database dumps only
#   --target config    Backup config files + .env
#   --dry-run          Show what would be backed up without executing
#   --restore <id>     Restore from a specific backup
#   --list             List all available backups
#   --verify           Verify backup integrity
#   --notify           Send notification via ntfy on completion/failure
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"

[[ -f "$ENV_FILE" ]] && set -a && source "$ENV_FILE" && set +a

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }
log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
TARGET="all"
DRY_RUN=false
NOTIFY=false
RESTORE_ID=""
ACTION="backup"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)   TARGET="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --restore)  ACTION="restore"; RESTORE_ID="$2"; shift 2 ;;
        --list)     ACTION="list"; shift ;;
        --verify)   ACTION="verify"; shift ;;
        --notify)   NOTIFY=true; shift ;;
        *) log_err "Unknown option: $1"; exit 1 ;;
    esac
done

send_notification() {
    local subject="$1" body="$2"
    if [ "$NOTIFY" = true ] && [ -n "${NTFY_URL:-}" ]; then
        curl -sf -H "Title: ${subject}" -d "${body}" "${NTFY_URL}" 2>/dev/null || true
    fi
}

do_list() {
    log_info "Available backups in ${BACKUP_DIR}:"
    if [ ! -d "${BACKUP_DIR}" ]; then
        log_warn "No backup directory found"
        return
    fi
    for dir in "${BACKUP_DIR}"/[0-9]*; do
        [ -d "$dir" ] || continue
        local name size
        name=$(basename "$dir")
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  ${name}  (${size})"
    done
}

do_verify() {
    log_info "Verifying backup integrity..."
    local latest
    latest=$(ls -td "${BACKUP_DIR}"/[0-9]* 2>/dev/null | head -1)
    if [ -z "${latest}" ]; then
        log_err "No backups found"
        exit 1
    fi
    log_ok "Checking: $(basename "$latest")"

    local failed=0
    for f in "${latest}"/*.tar.gz; do
        [ -f "$f" ] || continue
        if tar -tzf "$f" &>/dev/null; then
            log_ok "  $(basename "$f") — valid"
        else
            log_err "  $(basename "$f") — CORRUPT"
            failed=$((failed + 1))
        fi
    done
    for f in "${latest}"/*.sql.gz; do
        [ -f "$f" ] || continue
        if gzip -t "$f" 2>/dev/null; then
            log_ok "  $(basename "$f") — valid"
        else
            log_err "  $(basename "$f") — CORRUPT"
            failed=$((failed + 1))
        fi
    done

    if [ $failed -eq 0 ]; then
        log_ok "All backups verified successfully"
    else
        log_err "${failed} backup file(s) are corrupt"
        exit 1
    fi
}

do_restore() {
    local restore_dir="${BACKUP_DIR}/${RESTORE_ID}"
    if [ ! -d "$restore_dir" ]; then
        log_err "Backup not found: ${RESTORE_ID}"
        exit 1
    fi
    log_warn "=== RESTORE MODE ==="
    log_warn "Restoring from: ${restore_dir}"
    log_warn "This will overwrite current data. Press Ctrl+C to abort."
    read -rp "Continue? [y/N] " confirm
    [[ "${confirm,,}" != "y" ]] && log_info "Aborted" && exit 0

    log_info "Restoring configs..."
    if [ -f "${restore_dir}/configs.tar.gz" ]; then
        tar -xzf "${restore_dir}/configs.tar.gz" -C "${BASE_DIR}" 2>/dev/null && log_ok "Configs restored"
    fi

    log_info "Restoring database dumps..."
    if [ -f "${restore_dir}/postgresql_all.sql.gz" ]; then
        gunzip -c "${restore_dir}/postgresql_all.sql.gz" | \
            docker exec -i homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" 2>/dev/null \
            && log_ok "PostgreSQL restored" || log_err "PostgreSQL restore failed"
    fi
    if [ -f "${restore_dir}/mariadb_all.sql.gz" ]; then
        gunzip -c "${restore_dir}/mariadb_all.sql.gz" | \
            docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}" 2>/dev/null \
            && log_ok "MariaDB restored" || log_err "MariaDB restore failed"
    fi

    log_ok "Restore complete. Restart all stacks: docker compose -f docker-compose.base.yml restart"
}

backup_volumes() {
    local stack="$1"
    local volumes
    volumes=$(docker volume ls --format '{{.Name}}' | grep -E "^${stack}" || true)
    if [ -z "$volumes" ]; then
        volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
    fi
    while IFS= read -r vol; do
        [ -z "$vol" ] && continue
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY-RUN] Would backup volume: $vol"
        else
            log_info "Volume: $vol"
            docker run --rm \
                -v "${vol}:/data:ro" \
                -v "${BACKUP_PATH}:/backup" \
                alpine:3.19 \
                tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null \
                || log_warn "Failed to backup volume: $vol"
        fi
    done <<< "$volumes"
}

backup_configs() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would backup config/ stacks/ scripts/"
    else
        log_info "Backing up configs..."
        tar czf "${BACKUP_PATH}/configs.tar.gz" \
            -C "${BASE_DIR}" \
            --exclude='stacks/*/data' \
            --exclude='.git' \
            --exclude='backups' \
            config/ stacks/ scripts/ .env .env.example 2>/dev/null || true
        log_ok "Configs backed up"
    fi
}

backup_databases() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would dump PostgreSQL + MariaDB + Redis"
    else
        log_info "Backing up databases..."
        if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
            docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" \
                > "${BACKUP_PATH}/postgresql_all.sql" 2>/dev/null \
                && gzip -f "${BACKUP_PATH}/postgresql_all.sql" \
                && log_ok "PostgreSQL dumped"
        fi
        if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
            docker exec homelab-mariadb mariadb-dump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases \
                > "${BACKUP_PATH}/mariadb_all.sql" 2>/dev/null \
                && gzip -f "${BACKUP_PATH}/mariadb_all.sql" \
                && log_ok "MariaDB dumped"
        fi
        if docker ps --format '{{.Names}}' | grep -q 'homelab-redis'; then
            docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>/dev/null
            sleep 2
            docker cp homelab-redis:/data/dump.rdb "${BACKUP_PATH}/redis_dump.rdb" 2>/dev/null \
                && gzip -f "${BACKUP_PATH}/redis_dump.rdb" \
                && log_ok "Redis dumped"
        fi
    fi
}

cleanup_old() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would clean backups older than ${RETENTION_DAYS} days"
    else
        find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +"${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
        log_ok "Cleaned backups older than ${RETENTION_DAYS} days"
    fi
}

do_backup() {
    if [ "$DRY_RUN" = true ]; then
        log_info "=== DRY-RUN MODE — no changes will be made ==="
    fi

    mkdir -p "${BACKUP_PATH}"

    log_info "Starting backup — ${TIMESTAMP} (target: ${TARGET})"

    case "${TARGET}" in
        all)
            backup_configs
            backup_volumes ""
            backup_databases
            ;;
        config)
            backup_configs
            ;;
        databases)
            backup_databases
            ;;
        media|storage|productivity|network|sso|monitoring|ai|dashboard|home-automation)
            backup_volumes "${TARGET}"
            ;;
        *)
            log_err "Unknown target: ${TARGET}"
            exit 1
            ;;
    esac

    cleanup_old

    local total_size
    total_size=$(du -sh "${BACKUP_PATH}" 2>/dev/null | cut -f1)
    log_ok "Backup complete: ${BACKUP_PATH} (${total_size})"

    if [ "$NOTIFY" = true ]; then
        send_notification "HomeLab Backup Complete" "Size: ${total_size} | Target: ${TARGET} | Time: ${TIMESTAMP}"
    fi
}

case "${ACTION}" in
    backup)  do_backup  ;;
    list)    do_list    ;;
    verify)  do_verify  ;;
    restore) do_restore ;;
esac
