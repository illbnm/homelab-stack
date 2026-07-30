#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# E2E: Backup & Restore — Volume Backup/Restore Test
# ════════════════════════════════════════════════════════════════

BACKUP_DIR="${BACKUP_DIR:-/tmp/homelab-backup-test}"
TEST_VOLUME="homelab-backup-test"
TEST_FILE="test-backup-$(date +%s).txt"

test_create_test_volume() {
  docker volume create "$TEST_VOLUME" &>/dev/null
  assert_eq "$(docker volume ls --filter "name=^${TEST_VOLUME}$" --format '{{.Name}}')" "$TEST_VOLUME" "Test volume should be created"
}

test_write_test_data() {
  docker run --rm -v "${TEST_VOLUME}:/data" alpine sh -c "echo 'backup-test-content' > /data/${TEST_FILE}"
  assert_eq $? 0 "Should write test data to volume"
}

test_create_backup() {
  mkdir -p "$BACKUP_DIR"
  docker run --rm -v "${TEST_VOLUME}:/data" -v "${BACKUP_DIR}:/backup" alpine \
    tar czf "/backup/${TEST_VOLUME}.tar.gz" -C /data .
  assert_file_exists "${BACKUP_DIR}/${TEST_VOLUME}.tar.gz" "Backup archive should be created"
}

test_delete_test_data() {
  docker run --rm -v "${TEST_VOLUME}:/data" alpine rm -f "/data/${TEST_FILE}"
  # Verify file is gone
  local exists
  exists=$(docker run --rm -v "${TEST_VOLUME}:/data" alpine ls "/data/${TEST_FILE}" 2>/dev/null || echo "not_found")
  assert_eq "$exists" "not_found" "Test data should be deleted"
}

test_restore_backup() {
  docker run --rm -v "${TEST_VOLUME}:/data" -v "${BACKUP_DIR}:/backup" alpine \
    tar xzf "/backup/${TEST_VOLUME}.tar.gz" -C /data
  # Verify file is restored
  local content
  content=$(docker run --rm -v "${TEST_VOLUME}:/data" alpine cat "/data/${TEST_FILE}" 2>/dev/null || echo "")
  assert_eq "$content" "backup-test-content" "Restored data should match original"
}

test_cleanup() {
  docker volume rm "$TEST_VOLUME" &>/dev/null
  rm -rf "$BACKUP_DIR"
  return 0
}

test_postgres_backup() {
  if ! container_running postgres && ! container_running authentik-postgres; then
    return 1
  fi
  local pg_container
  pg_container=$(container_running postgres && echo "postgres" || echo "authentik-postgres")
  local result
  result=$(docker exec "$pg_container" pg_dump -U "${PG_USER:-postgres}" "${PG_DB:-postgres}" 2>/dev/null | head -5 || echo "")
  assert_contains "$result" "PostgreSQL database dump" "pg_dump should produce valid output"
}

test_redis_backup() {
  if ! container_running redis && ! container_running authentik-redis; then
    return 1
  fi
  local redis_container
  redis_container=$(container_running redis && echo "redis" || echo "authentik-redis")
  local result
  result=$(docker exec "$redis_container" redis-cli SAVE 2>/dev/null || echo "")
  assert_contains "$result" "OK" "Redis SAVE should succeed"
}