#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok()   { log "${GREEN}✓ $*${NC}"; }
warn() { log "${YELLOW}⚠ $*${NC}"; }
err()  { log "${RED}✗ $*${NC}"; }

usage() {
    cat <<EOF
Usage: restore.sh --target <stack> --backup-id <timestamp>

Options:
  --target <name>     Stack to restore (e.g. databases, media)
  --backup-id <id>    Backup timestamp (e.g. 20260319_020000)
  --help              Show this help
EOF
}

restore_volumes() {
    local stack="$1"
    local backup_id="$2"
    local src="${BACKUP_DIR}/${stack}/${backup_id}"

    [[ -d "$src" ]] || { err "Backup not found: $src"; return 1; }

    for vol_backup in "$src"/*.tar.gz; do
        [[ -f "$vol_backup" ]] || continue
        local vol_name
        vol_name=$(basename "$vol_backup" .tar.gz)
        log "Restoring volume: $vol_name"
        docker volume rm "$vol_name" 2>/dev/null || true
        docker volume create "$vol_name"
        docker run --rm -v "${vol_name}:/data" -v "$(dirname "$vol_backup"):/src" \
            alpine tar xzf "/src/$(basename "$vol_backup")" -C /data --strip-components=1
        ok "Restored $vol_name"
    done
}

restore_databases() {
    local backup_id="$1"
    local src="${BACKUP_DIR}/databases/${backup_id}"

    [[ -d "$src" ]] || { err "Database backup not found: $src"; return 1; }

    for dump in "$src"/*_pgdump.sql.gz; do
        [[ -f "$dump" ]] || continue
        local container
        container=$(basename "$dump" _pgdump.sql.gz)
        log "Restoring PostgreSQL: $container"
        gunzip -c "$dump" | docker exec -i "$container" psql -U "${POSTGRES_USER:-postgres}" && ok "Restored $container" || warn "Failed to restore $container"
    done

    for dump in "$src"/*_mysqldump.sql.gz; do
        [[ -f "$dump" ]] || continue
        local container
        container=$(basename "$dump" _mysqldump.sql.gz)
        log "Restoring MySQL: $container"
        gunzip -c "$dump" | docker exec -i "$container" mysql -u root && ok "Restored $container" || warn "Failed to restore $container"
    done
}

main() {
    local target="" backup_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target) target="$2"; shift 2 ;;
            --backup-id) backup_id="$2"; shift 2 ;;
            --help) usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    [[ -n "$target" && -n "$backup_id" ]] || { err "Missing --target or --backup-id"; usage; exit 1; }

    log "=== Restore Started: $target @ $backup_id ==="

    if [[ "$target" == "databases" ]]; then
        restore_databases "$backup_id"
    else
        restore_volumes "$target" "$backup_id"
    fi

    log "=== Restore Completed ==="
    log "Verify services: docker compose -f stacks/${target}/docker-compose.yml up -d"
}

main "$@"
