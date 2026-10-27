#!/usr/bin/env bash
set -euo pipefail

test_backup_script_syntax() {
  bash -n "$BASE_DIR/scripts/backup.sh"
}
