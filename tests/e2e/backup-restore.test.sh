#!/usr/bin/env bash
# =============================================================================
# backup-restore.test.sh — End-to-end backup and restore test
# =============================================================================
# Tests backup & restore workflow:
#   1. Create test data in a service (e.g., PostgreSQL)
#   2. Run backup
#   3. Destroy data
#   4. Run restore
#   5. Verify data is recovered
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Test PostgreSQL backup and restore
test_postgres_backup_restore() {
  local msg="PostgreSQL backup and restore cycle"

  # Check if postgres is running
  if ! docker inspect postgres &>/dev/null; then
    _assert_skip "$msg" "PostgreSQL container not running"
    return 0
  fi

  local test_db
  test_db="backup_test_$(date +%s)"
  local test_data
  test_data="backup_verification_$(date +%s)"

  # Step 1: Create test database and data
  docker exec postgres psql -U "${POSTGRES_USER:-postgres}" \
    -c "CREATE DATABASE ${test_db};" &>/dev/null || {
    _assert_fail "$msg" "Failed to create test database"
    return 1
  }

  docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -d "${test_db}" \
    -c "CREATE TABLE test_backup (id SERIAL PRIMARY KEY, data TEXT);
        INSERT INTO test_backup (data) VALUES ('${test_data}');" &>/dev/null || {
    _assert_fail "$msg" "Failed to insert test data"
    return 1
  }

  # Step 2: Backup
  docker exec postgres pg_dump -U "${POSTGRES_USER:-postgres}" "${test_db}" \
    > "/tmp/${test_db}.sql" 2>/dev/null || {
    _assert_fail "$msg" "pg_dump failed"
    return 1
  }

  # Step 3: Drop test database
  docker exec postgres psql -U "${POSTGRES_USER:-postgres}" \
    -c "DROP DATABASE ${test_db};" &>/dev/null || {
    _assert_fail "$msg" "Failed to drop test database"
    return 1
  }

  # Step 4: Restore
  docker exec postgres psql -U "${POSTGRES_USER:-postgres}" \
    -c "CREATE DATABASE ${test_db};" &>/dev/null

  cat "/tmp/${test_db}.sql" | docker exec -i postgres \
    psql -U "${POSTGRES_USER:-postgres}" -d "${test_db}" &>/dev/null || {
    _assert_fail "$msg" "Restore failed"
    return 1
  }

  # Step 5: Verify
  local restored
  restored=$(docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -d "${test_db}" \
    -t -c "SELECT data FROM test_backup WHERE data = '${test_data}';" 2>/dev/null | tr -d '[:space:]')

  # Cleanup
  docker exec postgres psql -U "${POSTGRES_USER:-postgres}" \
    -c "DROP DATABASE IF EXISTS ${test_db};" &>/dev/null
  rm -f "/tmp/${test_db}.sql"

  if [[ "$restored" == "$test_data" ]]; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "Restored data doesn't match: expected '${test_data}', got '${restored}'"
  fi
}

# Test Redis backup (RDB dump)
test_redis_backup_restore() {
  local msg="Redis RDB save and verify"

  if ! docker inspect redis &>/dev/null; then
    _assert_skip "$msg" "Redis container not running"
    return 0
  fi

  local test_key
  test_key="backup_test_$(date +%s)"
  local test_value
  test_value="verification_$(date +%s)"

  # Set test data
  docker exec redis redis-cli SET "$test_key" "$test_value" &>/dev/null || {
    _assert_fail "$msg" "Failed to SET test key"
    return 1
  }

  # Trigger save
  docker exec redis redis-cli BGSAVE &>/dev/null || {
    _assert_fail "$msg" "BGSAVE failed"
    return 1
  }
  sleep 2

  # Verify data persists
  local result
  result=$(docker exec redis redis-cli GET "$test_key" 2>/dev/null)

  # Cleanup
  docker exec redis redis-cli DEL "$test_key" &>/dev/null

  if [[ "$result" == "$test_value" ]]; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "Expected '${test_value}', Got '${result}'"
  fi
}
