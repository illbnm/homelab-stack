#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/report.sh"

echo "=== Running Monitoring Stack Tests ==="
assert_file_exists "stacks/monitoring/docker-compose.yml" && report_pass "monitoring/docker-compose.yml exists" || report_fail "monitoring/docker-compose.yml missing"
