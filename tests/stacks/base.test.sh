#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/report.sh"

echo "=== Running Base Stack Tests ==="
assert_file_exists "stacks/base/docker-compose.yml" && report_pass "base/docker-compose.yml exists" || report_fail "base/docker-compose.yml missing"
