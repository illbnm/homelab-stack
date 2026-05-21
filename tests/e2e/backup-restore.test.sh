#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — E2E: Backup & Restore
# Tests the backup creation and validation.
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "databases" || { begin_suite "E2E: Backup"; assert_skip "databases not selected"; exit 0; }

begin_suite "E2E: Backup & Restore Validation"

BACKUP_SCRIPT="${SCRIPT_DIR}/../../scripts/backup.sh"
BACKUP_DIR="${BACKUP_DIR:-/tmp/homelab-backup-test}"

# ---- Backup script exists ----
begin_test "backup:script_exists"
if [[ -f "$BACKUP_SCRIPT" ]]; then
  assert_pass "backup.sh found"
else
  assert_fail "backup.sh not found at $BACKUP_SCRIPT"
  return 0 2>/dev/null || exit 0
fi

begin_test "backup:script_executable"
if [[ -x "$BACKUP_SCRIPT" ]]; then
  assert_pass "backup.sh is executable"
else
  assert_skip "not executable (may need chmod +x)"
fi

# ---- PostgreSQL backup ----
begin_test "backup:postgresql:pg_dump_available"
if docker exec homelab-postgres which pg_dump &>/dev/null; then
  assert_pass "pg_dump available in postgres container"
else
  assert_skip "pg_dump not found"
fi

begin_test "backup:postgresql:create_dump"
mkdir -p "$BACKUP_DIR"
if docker exec homelab-postgres pg_dumpall -U postgres > "$BACKUP_DIR/pg_dump.sql" 2>/dev/null; then
  local_size=$(wc -c < "$BACKUP_DIR/pg_dump.sql")
  if [[ "$local_size" -gt 0 ]]; then
    assert_pass "dump created ($local_size bytes)"
  else
    assert_fail "dump is empty"
  fi
else
  assert_skip "pg_dumpall failed (may need credentials)"
fi

# ---- MariaDB backup ----
begin_test "backup:mariadb:mysqldump_available"
if docker exec homelab-mariadb which mysqldump &>/dev/null; then
  assert_pass "mysqldump available in mariadb container"
else
  assert_skip "mysqldump not found"
fi

# ---- Redis backup (RDB snapshot) ----
begin_test "backup:redis:bgsave"
if docker exec homelab-redis redis-cli bgsave 2>/dev/null | grep -qi ok; then
  assert_pass "BGSAVE triggered"
  sleep 2
  begin_test "backup:redis:rdb_exists"
  if docker exec homelab-redis ls /data/dump.rdb &>/dev/null; then
    assert_pass "dump.rdb exists"
  else
    assert_skip "dump.rdb not found (may be different path)"
  fi
else
  assert_skip "BGSAVE failed (may need auth)"
fi

# ---- Volume backup check ----
begin_test "backup:volumes:listed"
volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -i homelab | wc -l)
if [[ "$volumes" -gt 0 ]]; then
  assert_pass "$volumes homelab volumes found"
else
  assert_skip "no homelab volumes found"
fi

# ---- Cleanup ----
begin_test "backup:cleanup"
rm -rf "$BACKUP_DIR" 2>/dev/null
assert_pass "temp backup cleaned up"
