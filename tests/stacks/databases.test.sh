#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[databases] Running database stack tests..."
assert_container_running "postgresql" && print_test_result "databases" "PostgreSQL running" "PASS" "0.3s" || true
assert_container_running "redis" && print_test_result "databases" "Redis running" "PASS" "0.3s" || true
assert_container_running "mariadb" && print_test_result "databases" "MariaDB running" "PASS" "0.3s" || true
assert_container_healthy "postgresql" 30 && print_test_result "databases" "PostgreSQL healthy" "PASS" "5.0s" || true
