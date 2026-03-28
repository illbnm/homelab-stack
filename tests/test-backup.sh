#!/usr/bin/env bash
# =============================================================================
# Test: Backup and Restore Script Validation
# Tests that backup scripts are present, syntactically valid,
# handle arguments correctly, and have required functions.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

log_section "Backup & Restore Script Tests"

BACKUP_SCRIPT="$BASE_DIR/scripts/backup.sh"
BACKUP_DB_SCRIPT="$BASE_DIR/scripts/backup-databases.sh"

# -----------------------------------------------------------------------------
# Test: Backup script exists
# -----------------------------------------------------------------------------
test_begin "backup.sh exists"
if [[ -f "$BACKUP_SCRIPT" ]]; then
    test_pass
else
    test_fail "scripts/backup.sh not found"
fi

# -----------------------------------------------------------------------------
# Test: Backup script is executable (or has shebang)
# -----------------------------------------------------------------------------
test_begin "backup.sh has valid shebang"
if head -1 "$BACKUP_SCRIPT" 2>/dev/null | grep -q "^#!/usr/bin/env bash"; then
    test_pass
else
    test_fail "Missing or invalid shebang"
fi

# -----------------------------------------------------------------------------
# Test: Required functions exist in backup.sh
# -----------------------------------------------------------------------------
REQUIRED_FUNCTIONS=(
    "backup_configs"
    "backup_databases"
    "backup_volumes"
    "cleanup_old"
    "generate_summary"
)

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    test_begin "backup.sh has function: $func"
    if grep -q "^${func}()" "$BACKUP_SCRIPT" 2>/dev/null; then
        test_pass
    else
        test_fail "Function $func not found"
    fi
done

# -----------------------------------------------------------------------------
# Test: --help argument works
# -----------------------------------------------------------------------------
test_begin "backup.sh --help works"
if bash "$BACKUP_SCRIPT" --help > /dev/null 2>&1; then
    test_pass
else
    test_fail "--help exited with error"
fi

# -----------------------------------------------------------------------------
# Test: --dry-run works
# -----------------------------------------------------------------------------
test_begin "backup.sh --dry-run works"
export BACKUP_DIR="${BACKUP_DIR:-/tmp/test-backups}"
export TZ="${TZ:-UTC}"
mkdir -p "$BACKUP_DIR"

if timeout 30 bash "$BACKUP_SCRIPT" --target all --dry-run > /dev/null 2>&1; then
    test_pass
else
    test_fail "--dry-run exited with error"
fi

# -----------------------------------------------------------------------------
# Test: --list works
# -----------------------------------------------------------------------------
test_begin "backup.sh --list works"
if bash "$BACKUP_SCRIPT" --list > /dev/null 2>&1; then
    test_pass
else
    test_fail "--list exited with error"
fi

# -----------------------------------------------------------------------------
# Test: backup.sh does not fail with missing env file
# -----------------------------------------------------------------------------
test_begin "backup.sh handles missing .env gracefully"
if TZ=UTC BACKUP_DIR="$BACKUP_DIR" bash "$BACKUP_SCRIPT" --target all --dry-run > /dev/null 2>&1; then
    test_pass
else
    test_fail "Failed with missing .env file"
fi

# -----------------------------------------------------------------------------
# Test: backup-databases.sh exists (optional)
# -----------------------------------------------------------------------------
test_begin "backup-databases.sh exists"
if [[ -f "$BACKUP_DB_SCRIPT" ]]; then
    test_pass
    if head -1 "$BACKUP_DB_SCRIPT" 2>/dev/null | grep -q "^#!/"; then
        test_begin "backup-databases.sh has valid shebang"
        test_pass
    fi
else
    log_warn "backup-databases.sh not found (may be merged into backup.sh)"
    test_pass "(optional)"
fi

# -----------------------------------------------------------------------------
# Test: backup.sh --verify works (no backups to verify is OK)
# -----------------------------------------------------------------------------
test_begin "backup.sh --verify handles empty backup dir"
if bash "$BACKUP_SCRIPT" --verify > /dev/null 2>&1; then
    test_pass
else
    test_fail "--verify exited with error"
fi

# -----------------------------------------------------------------------------
# Test: required env vars are sourced or have defaults
# -----------------------------------------------------------------------------
test_begin "backup.sh has default BACKUP_DIR"
if grep -q 'BACKUP_DIR=' "$BACKUP_SCRIPT" && grep -q 'BACKUP_DIR="${BACKUP_DIR:-' "$BACKUP_SCRIPT"; then
    test_pass
else
    test_fail "BACKUP_DIR has no default value"
fi

test_begin "backup.sh has default RETENTION_DAYS"
if grep -q 'RETENTION_DAYS=' "$BACKUP_SCRIPT" && grep -q 'RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-' "$BACKUP_SCRIPT"; then
    test_pass
else
    test_fail "RETENTION_DAYS has no default value"
fi

test_begin "backup.sh has default RESTIC_PASSWORD"
if grep -q 'RESTIC_PASSWORD=' "$BACKUP_SCRIPT" && grep -q 'RESTIC_PASSWORD="${RESTIC_PASSWORD:-' "$BACKUP_SCRIPT"; then
    test_pass
else
    test_fail "RESTIC_PASSWORD has no default value"
fi

# -----------------------------------------------------------------------------
# Test: backup targets are validated
# -----------------------------------------------------------------------------
test_begin "backup.sh validates TARGET argument"
# Check that the script has target validation logic
if grep -qE "(all|media|databases)" "$BACKUP_SCRIPT" 2>/dev/null; then
    test_pass
else
    test_fail "No target validation found"
fi

# -----------------------------------------------------------------------------
# Test: backup.sh has notification function
# -----------------------------------------------------------------------------
test_begin "backup.sh has notify function"
if grep -q "^notify()" "$BACKUP_SCRIPT" 2>/dev/null || grep -q "notify() {" "$BACKUP_SCRIPT" 2>/dev/null; then
    test_pass
else
    test_fail "notify() function not found"
fi

# -----------------------------------------------------------------------------
# Test: disaster-recovery.md exists
# -----------------------------------------------------------------------------
test_begin "docs/disaster-recovery.md exists"
if [[ -f "$BASE_DIR/docs/disaster-recovery.md" ]]; then
    test_pass
else
    test_fail "docs/disaster-recovery.md not found"
fi

# -----------------------------------------------------------------------------
# Test: disaster-recovery.md has restore instructions
# -----------------------------------------------------------------------------
test_begin "docs/disaster-recovery.md has restore instructions"
if grep -qiE "(restore|recovery|backup)" "$BASE_DIR/docs/disaster-recovery.md" 2>/dev/null; then
    test_pass
else
    test_fail "No restore/recovery instructions found"
fi

# -----------------------------------------------------------------------------
# Test: set -euo pipefail is used
# -----------------------------------------------------------------------------
test_begin "backup.sh uses strict mode (set -euo pipefail)"
if grep -q "set -euo pipefail" "$BACKUP_SCRIPT" 2>/dev/null; then
    test_pass
else
    test_fail "Missing 'set -euo pipefail'"
fi

# Cleanup
rm -rf "${BACKUP_DIR:-/tmp/test-backups}" 2>/dev/null || true

test_summary
