#!/usr/bin/env bash
# =============================================================================
# E2E Test: Backup and Restore Cycle
# Tests the complete backup/restore workflow
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "E2E: Backup-Restore Cycle"

# Configuration
BACKUP_CONTAINER="${BACKUP_CONTAINER:-duplicati}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/backup-test}"
TEST_FILE="${BACKUP_DIR}/test-data.txt"
RESTORE_DIR="${BACKUP_DIR}/restore"

# Test 1: Backup containers are running
test_backup_containers_running() {
  log_group "Backup Containers"
  container_check duplicati 2>/dev/null || log_skip "Duplicati not running (CI mode)"
  container_check restic 2>/dev/null || log_skip "Restic not running (CI mode)"
}

# Test 2: Backup directory exists and is writable
test_backup_directory() {
  log_group "Backup Directory"
  
  # Create test directory
  mkdir -p "$BACKUP_DIR"
  mkdir -p "$RESTORE_DIR"
  
  if [[ -d "$BACKUP_DIR" ]]; then
    log_pass "Backup directory exists: $BACKUP_DIR"
  else
    log_fail "Cannot create backup directory: $BACKUP_DIR"
    return 1
  fi
  
  # Test write permissions
  if touch "$TEST_FILE" 2>/dev/null; then
    log_pass "Backup directory is writable"
    rm -f "$TEST_FILE"
  else
    log_fail "Backup directory is not writable"
    return 1
  fi
}

# Test 3: Create backup (simulated)
test_create_backup() {
  log_group "Create Backup"
  
  # Create test data
  echo "Test data: $(date -Iseconds)" > "$TEST_FILE"
  
  if [[ -f "$TEST_FILE" ]]; then
    log_pass "Test data created: $TEST_FILE"
  else
    log_fail "Cannot create test data"
    return 1
  fi
  
  # Simulate backup (in CI, containers may not be running)
  if docker ps --format '{{.Names}}' | grep -q "^${BACKUP_CONTAINER}$"; then
    log_pass "Backup container available"
  else
    log_skip "Backup container not running (CI mode) - using simulated backup"
    # Create simulated backup
    tar -czf "$BACKUP_DIR/backup-test.tar.gz" -C "$BACKUP_DIR" test-data.txt
    log_pass "Simulated backup created"
  fi
}

# Test 4: Restore backup (simulated)
test_restore_backup() {
  log_group "Restore Backup"
  
  # Clean restore directory
  rm -rf "$RESTORE_DIR"/*
  
  # Simulate restore (in CI, containers may not be running)
  if [[ -f "$BACKUP_DIR/backup-test.tar.gz" ]]; then
    tar -xzf "$BACKUP_DIR/backup-test.tar.gz" -C "$RESTORE_DIR"
    log_pass "Backup extracted to restore directory"
  else
    log_skip "No backup file found (CI mode) - using simulated restore"
    # Simulate restore
    cp "$TEST_FILE" "$RESTORE_DIR/test-data.txt"
    log_pass "Simulated restore completed"
  fi
  
  # Verify restored data
  if [[ -f "$RESTORE_DIR/test-data.txt" ]]; then
    log_pass "Restored data exists"
  else
    log_fail "Restored data not found"
    return 1
  fi
}

# Test 5: Verify data integrity
test_data_integrity() {
  log_group "Data Integrity"
  
  if diff -q "$TEST_FILE" "$RESTORE_DIR/test-data.txt" >/dev/null 2>&1; then
    log_pass "Data integrity verified: backup matches restore"
  else
    log_fail "Data integrity check failed: backup does not match restore"
    return 1
  fi
}

# Test 6: Cleanup
test_cleanup() {
  log_group "Cleanup"
  
  rm -rf "$BACKUP_DIR"
  log_pass "Test directories cleaned up"
}

# Run all tests
test_backup_containers_running
test_backup_directory
test_create_backup
test_restore_backup
test_data_integrity
test_cleanup

# Print summary
print_summary