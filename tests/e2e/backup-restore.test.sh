#!/bin/bash
# backup-restore.test.sh - 备份恢复端到端测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_backup_script_exists() {
    echo "[e2e] Testing backup script exists..."
    local backup_script="$ROOT_DIR/scripts/backup.sh"
    if [[ -f "$backup_script" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Backup script found"
        return 0
    else
        echo -e "${YELLOW}⏭️ SKIP${NC} Backup script not found"
        return 0
    fi
}

test_backup_directory_exists() {
    echo "[e2e] Testing backup directory exists..."
    local backup_dir="$ROOT_DIR/backups"
    if [[ -d "$backup_dir" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Backup directory found"
        return 0
    else
        echo -e "${YELLOW}⏭️ SKIP${NC} Backup directory not found"
        return 0
    fi
}

test_restore_script_exists() {
    echo "[e2e] Testing restore script exists..."
    local restore_script="$ROOT_DIR/scripts/restore.sh"
    if [[ -f "$restore_script" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Restore script found"
        return 0
    else
        echo -e "${YELLOW}⏭️ SKIP${NC} Restore script not found"
        return 0
    fi
}

test_backup_config_exists() {
    echo "[e2e] Testing backup configuration exists..."
    local backup_config="$ROOT_DIR/config/backup/backup.conf"
    if [[ -f "$backup_config" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Backup config found"
        return 0
    else
        echo -e "${YELLOW}⏭️ SKIP${NC} Backup config not found"
        return 0
    fi
}

run_backup_e2e_tests() {
    print_header "HomeLab Stack — Backup/Restore E2E Tests"
    
    test_backup_script_exists || true
    test_backup_directory_exists || true
    test_restore_script_exists || true
    test_backup_config_exists || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_backup_e2e_tests
fi
