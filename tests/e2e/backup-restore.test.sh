#!/usr/bin/env bash
assert_suite "e2e/backup-restore"

test_backup_script_exists() {
    assert_test "backup script is executable"
    local script="$(cd "$(dirname "$0")/../../.." && pwd)/scripts/backup.sh"
    if [[ -x "$script" ]]; then
        _pass
    else
        _fail "backup.sh not found or not executable"
    fi
}

test_backup_dry_run() {
    assert_test "backup script --dry-run succeeds"
    local script="$(cd "$(dirname "$0")/../../.." && pwd)/scripts/backup.sh"
    if [[ -x "$script" ]]; then
        if "$script" --dry-run 2>/dev/null; then
            _pass
        else
            _fail "backup.sh --dry-run failed"
        fi
    else
        _skip "backup.sh not found"
    fi
}

test_backup_script_exists
test_backup_dry_run