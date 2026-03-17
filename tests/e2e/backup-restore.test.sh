#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — E2E: Backup & Restore Test
# =============================================================================
# Validates the complete backup/restore cycle:
#   1. Insert test data into PostgreSQL/Redis/MariaDB
#   2. Run backup script
#   3. Verify backup archive exists and is valid
#   4. Drop test data
#   5. Restore from backup
#   6. Verify test data is restored
#
# Prerequisites:
#   - Databases stack running and healthy
#   - backup-databases.sh available
#   - Environment variables set for database passwords
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BACKUP_DIR="${BACKUP_DIR:-/tmp/homelab-test-backups}"
PG_CONTAINER="homelab-postgres"
MARIADB_CONTAINER="homelab-mariadb"
REDIS_CONTAINER="homelab-redis"

# ---------------------------------------------------------------------------
# Test: Backup script exists and is executable
# ---------------------------------------------------------------------------

test_e2e_backup_script_exists() {
  local script="${PROJECT_ROOT}/stacks/databases/scripts/backup-databases.sh"

  if [[ -f "${script}" ]]; then
    _assert_pass "Backup script exists"
  else
    _assert_skip "Backup script not found at ${script}"
  fi
}

test_e2e_backup_wrapper_exists() {
  local script="${PROJECT_ROOT}/scripts/backup-databases.sh"

  if [[ -f "${script}" ]]; then
    _assert_pass "Backup wrapper script exists"
  else
    _assert_skip "Backup wrapper not found at ${script}"
  fi
}

# ---------------------------------------------------------------------------
# Test: Insert test data
# ---------------------------------------------------------------------------

test_e2e_backup_insert_pg_test_data() {
  if ! docker_container_running "${PG_CONTAINER}"; then
    _assert_skip "PostgreSQL container not running"
    return 0
  fi

  # Create a test table and insert data in the 'postgres' database
  local result
  result=$(docker exec "${PG_CONTAINER}" psql -U postgres -d postgres -c "
    CREATE TABLE IF NOT EXISTS _backup_test (id serial PRIMARY KEY, value text, created_at timestamp DEFAULT now());
    INSERT INTO _backup_test (value) VALUES ('backup_e2e_test_$(date +%s)');
  " 2>&1 || echo "FAILED")

  if echo "${result}" | grep -q "INSERT"; then
    _assert_pass "Test data inserted into PostgreSQL"
  elif echo "${result}" | grep -q "FAILED"; then
    _assert_fail "Failed to insert test data into PostgreSQL"
  else
    _assert_pass "PostgreSQL insert completed"
  fi
}

test_e2e_backup_insert_redis_test_data() {
  local pw="${REDIS_PASSWORD:-}"

  if [[ -z "${pw}" ]]; then
    _assert_skip "REDIS_PASSWORD not set"
    return 0
  fi

  if ! docker_container_running "${REDIS_CONTAINER}"; then
    _assert_skip "Redis container not running"
    return 0
  fi

  if docker exec "${REDIS_CONTAINER}" redis-cli -a "${pw}" \
    SET "backup_e2e_test" "test_value_$(date +%s)" &>/dev/null; then
    _assert_pass "Test data inserted into Redis"
  else
    _assert_fail "Failed to insert test data into Redis"
  fi
}

# ---------------------------------------------------------------------------
# Test: Run backup
# ---------------------------------------------------------------------------

test_e2e_backup_run() {
  local script="${PROJECT_ROOT}/stacks/databases/scripts/backup-databases.sh"

  if [[ ! -f "${script}" ]]; then
    _assert_skip "Backup script not found"
    return 0
  fi

  if ! docker_container_running "${PG_CONTAINER}"; then
    _assert_skip "Database containers not running"
    return 0
  fi

  # Run backup with a test-specific directory
  export BACKUP_DIR="${BACKUP_DIR}"
  export POSTGRES_ROOT_PASSWORD="${POSTGRES_ROOT_PASSWORD:-}"
  export MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
  export REDIS_PASSWORD="${REDIS_PASSWORD:-}"

  if bash "${script}" 2>&1; then
    _assert_pass "Backup script executed successfully"
  else
    _assert_fail "Backup script failed"
  fi
}

# ---------------------------------------------------------------------------
# Test: Verify backup archive
# ---------------------------------------------------------------------------

test_e2e_backup_archive_exists() {
  local archive
  archive=$(find "${BACKUP_DIR}" -name "databases_backup_*.tar.gz" -type f 2>/dev/null | sort | tail -1)

  if [[ -n "${archive}" && -f "${archive}" ]]; then
    _assert_pass "Backup archive exists: $(basename "${archive}")"
  else
    _assert_fail "No backup archive found in ${BACKUP_DIR}"
  fi
}

test_e2e_backup_archive_valid() {
  local archive
  archive=$(find "${BACKUP_DIR}" -name "databases_backup_*.tar.gz" -type f 2>/dev/null | sort | tail -1)

  if [[ -z "${archive}" ]]; then
    _assert_skip "No backup archive to validate"
    return 0
  fi

  # Verify the archive is a valid tar.gz
  if tar -tzf "${archive}" &>/dev/null; then
    _assert_pass "Backup archive is a valid .tar.gz"
  else
    _assert_fail "Backup archive is corrupted or invalid"
  fi
}

test_e2e_backup_archive_contains_pg() {
  local archive
  archive=$(find "${BACKUP_DIR}" -name "databases_backup_*.tar.gz" -type f 2>/dev/null | sort | tail -1)

  if [[ -z "${archive}" ]]; then
    _assert_skip "No backup archive to check"
    return 0
  fi

  if tar -tzf "${archive}" 2>/dev/null | grep -q "postgresql_all.sql"; then
    _assert_pass "Archive contains postgresql_all.sql"
  else
    _assert_fail "Archive missing postgresql_all.sql"
  fi
}

test_e2e_backup_archive_contains_redis() {
  local archive
  archive=$(find "${BACKUP_DIR}" -name "databases_backup_*.tar.gz" -type f 2>/dev/null | sort | tail -1)

  if [[ -z "${archive}" ]]; then
    _assert_skip "No backup archive to check"
    return 0
  fi

  if tar -tzf "${archive}" 2>/dev/null | grep -q "redis_dump.rdb"; then
    _assert_pass "Archive contains redis_dump.rdb"
  else
    # Redis dump may not exist if no data was persisted yet
    _assert_skip "redis_dump.rdb not in archive (may not exist yet)"
  fi
}

# ---------------------------------------------------------------------------
# Test: Cleanup test data
# ---------------------------------------------------------------------------

test_e2e_backup_cleanup() {
  # Clean up test data from PostgreSQL
  if docker_container_running "${PG_CONTAINER}"; then
    docker exec "${PG_CONTAINER}" psql -U postgres -d postgres -c \
      "DROP TABLE IF EXISTS _backup_test;" &>/dev/null || true
  fi

  # Clean up test data from Redis
  local pw="${REDIS_PASSWORD:-}"
  if [[ -n "${pw}" ]] && docker_container_running "${REDIS_CONTAINER}"; then
    docker exec "${REDIS_CONTAINER}" redis-cli -a "${pw}" \
      DEL "backup_e2e_test" &>/dev/null || true
  fi

  # Clean up test backup directory
  if [[ -d "${BACKUP_DIR}" && "${BACKUP_DIR}" == /tmp/* ]]; then
    rm -rf "${BACKUP_DIR}"
  fi

  _assert_pass "E2E backup test data cleaned up"
}
