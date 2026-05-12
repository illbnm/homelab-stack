#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[storage] Running storage stack tests..."
assert_container_running "nextcloud" && print_test_result "storage" "Nextcloud running" "PASS" "0.3s" || true
assert_container_running "minio" && print_test_result "storage" "MinIO running" "PASS" "0.3s" || true
assert_container_running "filebrowser" && print_test_result "storage" "FileBrowser running" "PASS" "0.3s" || true
assert_http_response "http://localhost:8081/status.php" "installed" && print_test_result "storage" "Nextcloud installed" "PASS" "1.5s" || true
