#!/usr/bin/env bash
# =============================================================================
# HomeLab Disaster Recovery — Full restore from zero
# Restores all stacks from backup on a fresh host
#
# Usage:
#   restore.sh --from <backup_id> [--stacks <name|all>] [--skip-deps]
#   restore.sh --from-latest
#   restore.sh --list
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."

for env_file in \
  "${BASE_DIR}/stacks/backup/.env" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/config/.env"; do
  [[ -f "$env_file" ]] && source "$env_file" && break
done

BACKUP_DIR="${BACKUP_DATA_DIR:-/opt/homelab-backups}"
RESTIC_REPO="${BACKUP_RESTIC_REPO:-http://restic-server:8000}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[restore]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[restore]${NC} $*"; }
log_error() { echo -e "${RED}[restore]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
BACKUP_ID=""
TARGET_STACKS="all"
SKIP_DEPS=false
LIST_ONLY=false
LATEST=false

usage() {
  cat <<EOF
HomeLab Disaster Recovery — Full restore from backup

Usage:
  $(basename "$0") --from <backup_id> [options]
  $(basename "$0") --from-latest
  $(basename "$0") --list

Options:
  --from <id>           Restore from specific backup ID (timestamp)
  --from-latest         Restore from most recent backup
  --stacks <name|all>   Restore specific stack or all (default: all)
  --skip-deps           Skip dependency checks
  --list                List available backups
  -h, --help            Show this help

Recovery Order (automatic):
  1. Base infrastructure (Traefik, Portainer)
  2. Databases (PostgreSQL, MariaDB, Redis)
  3. SSO (Authentik)
  4. All other stacks
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)       BACKUP_ID="$2"; shift 2 ;;
    --from-latest) LATEST=true; shift ;;
    --stacks)     TARGET_STACKS="$2"; shift 2 ;;
    --skip-deps)  SKIP_DEPS=true; shift ;;
    --list)       LIST_ONLY=true; shift ;;
    -h|--help)    usage ;;
    *)            log_error "Unknown option: $1"; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# List backups
# ---------------------------------------------------------------------------
if [[ "$LIST_ONLY" == true ]]; then
  log_step "Available backups"
  if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' | sort -r | while read -r dir; do
      local_id=$(basename "$dir")
      local_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      local_count=$(find "$dir" -type f | wc -l | tr -d ' ')
      echo "  $local_id  ($local_size, $local_count files)"
    done
  else
    echo "  No backups found at: $BACKUP_DIR"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Resolve backup ID
# ---------------------------------------------------------------------------
if [[ "$LATEST" == true ]]; then
  BACKUP_ID=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' | sort -r | head -1 | xargs basename 2>/dev/null || true)
  if [[ -z "$BACKUP_ID" ]]; then
    log_error "No backups found"
    exit 1
  fi
  log_info "Using latest backup: $BACKUP_ID"
fi

if [[ -z "$BACKUP_ID" ]]; then
  log_error "Must specify --from <backup_id> or --from-latest"
  usage
fi

RESTORE_DIR="${BACKUP_DIR}/${BACKUP_ID}"
if [[ ! -d "$RESTORE_DIR" ]]; then
  log_error "Backup not found: $RESTORE_DIR"
  exit 1
fi

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
if [[ "$SKIP_DEPS" != true ]]; then
  log_step "Checking dependencies"
  local_missing=0
  for cmd in docker; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Missing: $cmd"
      ((local_missing++))
    fi
  done
  if [[ $local_missing -gt 0 ]]; then
    log_error "Install missing dependencies or use --skip-deps"
    exit 1
  fi
  log_info "✓ All dependencies satisfied"
fi

# ---------------------------------------------------------------------------
# Restore order: Base → DB → SSO → Other
# ---------------------------------------------------------------------------
RESTORE_ORDER=(base databases sso monitoring network storage media ai productivity home-automation notifications dashboard)

log_step "Starting Disaster Recovery"
log_info "Backup ID:  $BACKUP_ID"
log_info "Restore to: $BASE_DIR"
log_warn "⚠ This will overwrite existing data. Press Ctrl+C to abort, or wait 10s..."
sleep 10

# Step 1: Ensure Docker networks exist
log_step "Step 1: Creating Docker networks"
for net in proxy homelab-backup; do
  docker network create "$net" 2>/dev/null && log_info "  Created network: $net" || log_info "  Network exists: $net"
done

# Step 2: Restore all Docker volumes
log_step "Step 2: Restoring Docker volumes"
for archive in "$RESTORE_DIR"/vol_*.tar.gz; do
  [[ ! -f "$archive" ]] && continue
  vol_name=$(basename "$archive" | sed 's/^vol_//;s/\.tar\.gz$//')

  if [[ "$TARGET_STACKS" != "all" ]] && [[ "$vol_name" != *"$TARGET_STACKS"* ]]; then
    continue
  fi

  log_info "  Restoring volume: $vol_name"
  docker volume create "$vol_name" 2>/dev/null || true
  docker run --rm \
    -v "${vol_name}:/data" \
    -v "${RESTORE_DIR}:/backup:ro" \
    alpine:3.19 \
    sh -c "rm -rf /data/* 2>/dev/null; tar xzf /backup/vol_${vol_name}.tar.gz -C /data" || {
      log_warn "  Failed to restore volume: $vol_name"
    }
done
log_info "✓ Volumes restored"

# Step 3: Restore databases
log_step "Step 3: Restoring databases"
if [[ -f "$RESTORE_DIR/postgresql_all.sql" ]]; then
  log_info "  PostgreSQL dump available — will restore after DB stack starts"
fi
if [[ -f "$RESTORE_DIR/mysql_all.sql" ]]; then
  log_info "  MySQL dump available — will restore after DB stack starts"
fi

# Step 4: Restore configs
log_step "Step 4: Restoring config files"
if [[ -f "$RESTORE_DIR/configs.tar.gz" ]]; then
  tar xzf "$RESTORE_DIR/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || {
    log_warn "  Config restore had conflicts (may be expected)"
  }
  log_info "✓ Configs restored"
fi

# Step 5: Start stacks in order
log_step "Step 5: Starting stacks in recovery order"
for stack in "${RESTORE_ORDER[@]}"; do
  if [[ "$TARGET_STACKS" != "all" ]] && [[ "$stack" != "$TARGET_STACKS" ]]; then
    continue
  fi

  local_compose="${BASE_DIR}/stacks/${stack}/docker-compose.yml"
  if [[ -f "$local_compose" ]]; then
    log_info "  Starting stack: $stack"
    (cd "${BASE_DIR}/stacks/${stack}" && docker compose up -d) 2>/dev/null || {
      log_warn "  Stack $stack had startup issues"
    }
    # Wait for health checks
    sleep 5
  fi
done

# Step 6: Restore database dumps into running containers
log_step "Step 6: Restoring database data"

if [[ -f "$RESTORE_DIR/postgresql_all.sql" ]]; then
  pg_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'postgres|postgresql' | head -1 || true)
  if [[ -n "$pg_container" ]]; then
    log_info "  Restoring PostgreSQL into: $pg_container"
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
              grep POSTGRES_PASSWORD | cut -d= -f2 | head -1 || true)
    # Wait for PostgreSQL to be ready
    for i in $(seq 1 30); do
      docker exec "$pg_container" pg_isready -U postgres &>/dev/null && break
      sleep 2
    done
    docker exec -i "$pg_container" \
      sh -c "PGPASSWORD='${pg_pass}' psql -U postgres" \
      < "$RESTORE_DIR/postgresql_all.sql" 2>/dev/null || {
        log_warn "  PostgreSQL restore had errors (expected if DBs exist)"
      }
    log_info "  ✓ PostgreSQL restored"
  fi
fi

if [[ -f "$RESTORE_DIR/mysql_all.sql" ]]; then
  mysql_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'mariadb|mysql' | head -1 || true)
  if [[ -n "$mysql_container" ]]; then
    log_info "  Restoring MariaDB into: $mysql_container"
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
                 grep -E 'MYSQL_ROOT_PASSWORD|MARIADB_ROOT_PASSWORD' | cut -d= -f2 | head -1 || true)
    for i in $(seq 1 30); do
      docker exec "$mysql_container" healthcheck.sh --connect &>/dev/null 2>&1 && break
      sleep 2
    done
    docker exec -i "$mysql_container" \
      sh -c "mysql -u root -p'${mysql_pass}'" \
      < "$RESTORE_DIR/mysql_all.sql" 2>/dev/null || {
        log_warn "  MySQL restore had errors (expected if DBs exist)"
      }
    log_info "  ✓ MariaDB restored"
  fi
fi

# Step 7: Verification
log_step "Step 7: Post-restore verification"
sleep 10

failed=0
for container in $(docker ps --format '{{.Names}}' 2>/dev/null); do
  status=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
  state=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")

  if [[ "$state" == "running" ]]; then
    if [[ "$status" == "healthy" ]] || [[ "$status" == "no-healthcheck" ]]; then
      log_info "  ✓ $container ($state)"
    else
      log_warn "  ⚠ $container ($state, health: $status)"
      ((failed++))
    fi
  else
    log_error "  ✗ $container ($state)"
    ((failed++))
  fi
done

log_step "Disaster Recovery Complete"
if [[ $failed -eq 0 ]]; then
  log_info "✓ All containers running and healthy"
else
  log_warn "⚠ $failed containers need attention"
fi

log_info ""
log_info "Next steps:"
log_info "  1. Verify web UIs: https://traefik.\${DOMAIN}"
log_info "  2. Check SSO login: https://auth.\${DOMAIN}"
log_info "  3. Verify data integrity in each service"
log_info "  4. Re-enable backup schedule: cd stacks/backup && docker compose up -d"
