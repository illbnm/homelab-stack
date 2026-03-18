#!/usr/bin/env bash
# backup-restore.test.sh - End-to-end backup and restore test
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT
#
# Simulates backup creation, data modification, restore, and verification:
# 1. Create a test backup
# 2. Modify data in a service
# 3. Restore from backup
# 4. Verify data integrity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="e2e-backup-restore"
BACKUP_DIR="/tmp/homelab-stack/test-backups"
TEST_SERVICE="portainer"
TEST_DATA_FILE="/tmp/homelab-stack/test-data-marker.txt"

setup() {
    assert_reset
    report_init "$STACK_NAME"
    mkdir -p "$BACKUP_DIR"
}

teardown() {
    report_write_json
    report_print_summary
    # Cleanup test artifacts
    rm -rf "${BACKUP_DIR}"
    rm -f "${TEST_DATA_FILE}"
}

# Step 1: Verify backup directory can be created
test_backup_dir_creation() {
    assert_set_test "backup_dir_creation"
    mkdir -p "$BACKUP_DIR"
    assert_dir_exists "$BACKUP_DIR" "backup directory should be created"
}

# Step 2: Create a test data marker
test_create_test_data() {
    assert_set_test "create_test_data"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "test-backup-marker: ${timestamp}" > "$TEST_DATA_FILE"
    assert_file_exists "$TEST_DATA_FILE" "test data marker file should exist"
}

# Step 3: Simulate backing up a container volume
test_simulate_volume_backup() {
    assert_set_test "simulate_volume_backup"
    local container="$TEST_SERVICE"
    local running
    running=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container" && echo "yes" || echo "no")

    if [ "$running" = "yes" ]; then
        # Create a tar backup of container's data directory
        local backup_file="${BACKUP_DIR}/${container}-backup-$(date +%s).tar.gz"
        local data_dir
        data_dir=$(docker inspect --format '{{range .Mounts}}{{.Source}}{{end}}' "$container" 2>/dev/null | head -1) || true

        if [ -n "$data_dir" ] && [ -d "$data_dir" ]; then
            tar -czf "$backup_file" -C "$(dirname "$data_dir")" "$(basename "$data_dir")" 2>/dev/null
            assert_file_exists "$backup_file" "volume backup should be created"
            echo "$backup_file" > "${BACKUP_DIR}/last-backup.txt"
        else
            _assert_skip "volume backup" "no data mounts found for ${container}"
        fi
    else
        _assert_skip "volume backup" "${container} not running"
    fi
}

# Step 4: Verify backup file integrity
test_backup_integrity() {
    assert_set_test "backup_integrity"
    local backup_file
    backup_file=$(cat "${BACKUP_DIR}/last-backup.txt" 2>/dev/null) || true

    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        # Verify tar is valid
        if tar -tzf "$backup_file" &>/dev/null; then
            _assert_pass "backup file integrity verified"
        else
            _assert_fail "backup integrity" "tar file is corrupted"
        fi
        # Check file size is non-zero
        local size
        size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        assert_ne "$size" "0" "backup file should not be empty"
    else
        _assert_skip "backup integrity" "no backup file from previous step"
    fi
}

# Step 5: Simulate data modification detection
test_detect_modification() {
    assert_set_test "detect_modification"
    local backup_file
    backup_file=$(cat "${BACKUP_DIR}/last-backup.txt" 2>/dev/null) || true

    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        # Modify the test marker to simulate change
        echo "modified: $(date -u +%s)" >> "$TEST_DATA_FILE"
        local lines
        lines=$(wc -l < "$TEST_DATA_FILE")
        assert_ne "$lines" "1" "modified file should have more lines"
    else
        _assert_skip "modification detection" "no backup file from previous step"
    fi
}

# Step 6: Simulate restore verification
test_restore_verification() {
    assert_set_test "restore_verification"
    local backup_file
    backup_file=$(cat "${BACKUP_DIR}/last-backup.txt" 2>/dev/null) || true

    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        # Extract backup to a temp dir for verification
        local restore_dir="${BACKUP_DIR}/restore-verify"
        mkdir -p "$restore_dir"
        tar -xzf "$backup_file" -C "$restore_dir" 2>/dev/null
        assert_dir_exists "$restore_dir" "restore directory should exist"
        # Verify at least one file was extracted
        local file_count
        file_count=$(find "$restore_dir" -type f 2>/dev/null | wc -l)
        assert_ne "$file_count" "0" "restored data should contain files"
        rm -rf "$restore_dir"
    else
        _assert_skip "restore verification" "no backup file from previous step"
    fi
}

# Step 7: Cleanup and verify
test_cleanup() {
    assert_set_test "cleanup"
    rm -f "${TEST_DATA_FILE}"
    assert_exit_code 1 "test -f '${TEST_DATA_FILE}'"
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
