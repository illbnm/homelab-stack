#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/report.sh"

echo "=== Running Database Stack Tests ==="
assert_file_exists "stacks/databases/docker-compose.yml" && report_pass "databases/docker-compose.yml exists" || report_fail "databases/docker-compose.yml missing"
