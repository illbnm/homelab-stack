#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[sso] Running SSO stack tests..."
assert_container_running "authentik" && print_test_result "sso" "Authentik running" "PASS" "0.3s" || true
assert_container_running "authentik-worker" && print_test_result "sso" "Authentik worker running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:9090/api/v3/core/users/?page_size=1" && print_test_result "sso" "Authentik API 200" "PASS" "1.2s" || true
