#!/usr/bin/env bash
# =============================================================================
# backup-restore.test.sh — Backup and restore end-to-end test
# =============================================================================

test_suite "E2E — Backup & Restore"

test_backup_script_exists() {
  assert_file_exists "$BASE_DIR/scripts/backup.sh" "backup.sh script exists"
}

test_backup_databases_script_exists() {
  assert_file_exists "$BASE_DIR/scripts/backup-databases.sh" "backup-databases.sh script exists"
}

test_backup_script_executable() {
  if [[ -x "$BASE_DIR/scripts/backup.sh" ]]; then
    test_pass "backup.sh is executable"
  else
    test_fail "backup.sh is executable" "missing execute permission"
  fi
}

test_backup_databases_script_executable() {
  if [[ -x "$BASE_DIR/scripts/backup-databases.sh" ]]; then
    test_pass "backup-databases.sh is executable"
  else
    test_fail "backup-databases.sh is executable" "missing execute permission"
  fi
}

test_postgres_dump_capability() {
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-postgres$"; then
    test_skip "PostgreSQL pg_dump" "container not running"
    return
  fi
  local result
  result=$(docker_run_in "homelab-postgres" \
    pg_dump --version 2>/dev/null || echo "")
  if [[ "$result" == *"pg_dump"* ]]; then
    test_pass "PostgreSQL pg_dump is available"
  else
    test_fail "PostgreSQL pg_dump" "pg_dump not found in container"
  fi
}

test_redis_save_capability() {
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-redis$"; then
    test_skip "Redis BGSAVE" "container not running"
    return
  fi
  local result
  result=$(docker_run_in "homelab-redis" redis-cli BGSAVE 2>/dev/null || echo "")
  if [[ "$result" == *"Background saving"* || "$result" == *"already in progress"* ]]; then
    test_pass "Redis BGSAVE works"
  else
    test_fail "Redis BGSAVE" "unexpected response: $result"
  fi
}

test_backup_script_exists
test_backup_databases_script_exists
test_backup_script_executable
test_backup_databases_script_executable
test_postgres_dump_capability
test_redis_save_capability
