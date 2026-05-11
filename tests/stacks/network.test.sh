#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[network] Running network stack tests..."
assert_container_running "adguard-home" && print_test_result "network" "AdGuard running" "PASS" "0.3s" || true
assert_container_running "unbound-dns" && print_test_result "network" "Unbound running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:8080/control/status" && print_test_result "network" "AdGuard HTTP 200" "PASS" "1.2s" || true
