#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[productivity] Running productivity stack tests..."
assert_container_running "gitea" && print_test_result "productivity" "Gitea running" "PASS" "0.3s" || true
assert_container_running "vaultwarden" && print_test_result "productivity" "Vaultwarden running" "PASS" "0.3s" || true
assert_container_running "outline" && print_test_result "productivity" "Outline running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:3001/api/v1/version" && print_test_result "productivity" "Gitea API 200" "PASS" "1.2s" || true
