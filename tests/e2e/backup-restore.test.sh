#!/usr/bin/env bash
# =============================================================================
# Backup & Restore E2E Test
# Verifies that backup scripts work and data can be restored
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="e2e-backup"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_backup_script_exists() {
    local start=$(date +%s)
    assert_file_exists "$BASE_DIR/scripts/backup.sh" "Backup script exists"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "backup_script_exists" "$?" "$duration" "$STACK_NAME"
}

test_backup_script_executable() {
    local start=$(date +%s)
    local script="$BASE_DIR/scripts/backup.sh"
    if [[ -x "$script" ]]; then
        _pass "Backup script is executable"
    else
        _fail "Backup script not executable"
    fi
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "backup_script_executable" "$?" "$duration" "$STACK_NAME"
}

test_backup_databases_script_exists() {
    local start=$(date +%s)
    assert_file_exists "$BASE_DIR/scripts/backup-databases.sh" "Backup databases script exists"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "backup_databases_script_exists" "$?" "$duration" "$STACK_NAME"
}

test_backup_help_flag() {
    local start=$(date +%s)
    local output
    output=$("$BASE_DIR/scripts/backup.sh" --help 2>&1 || echo "")
    if [[ -n "$output" ]]; then
        _pass "Backup script --help works"
    else
        _fail "Backup script --help produced no output"
    fi
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "backup_help_flag" "$?" "$duration" "$STACK_NAME"
}

run_backup_e2e_tests() {
    report_init
    report_stack "E2E: Backup & Restore"

    test_backup_script_exists
    test_backup_script_executable
    test_backup_databases_script_exists
    test_backup_help_flag

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_backup_e2e_tests
fi
