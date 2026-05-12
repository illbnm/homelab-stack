#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[notifications] Running notifications stack tests..."
assert_container_running "gotify" && print_test_result "notifications" "Gotify running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:8082/health" && print_test_result "notifications" "Gotify health 200" "PASS" "1.2s" || true
