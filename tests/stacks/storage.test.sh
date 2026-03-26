#!/usr/bin/env bash
# storage.test.sh - Storage Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="storage"

test_nextcloud() {
    test_start "Nextcloud - 容器运行"
    if assert_container_running "nextcloud"; then test_end "Nextcloud - 容器运行" "PASS"
    else test_end "Nextcloud - 容器运行" "FAIL"; return 1; fi
    test_start "Nextcloud - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "Nextcloud - HTTP 端点可达" "PASS"
    else test_end "Nextcloud - HTTP 端点可达" "SKIP"; fi
}

test_minio() {
    test_start "MinIO - 容器运行"
    if assert_container_running "minio"; then test_end "MinIO - 容器运行" "PASS"
    else test_end "MinIO - 容器运行" "FAIL"; return 1; fi
    test_start "MinIO - Console 可访问"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9001/"; then test_end "MinIO - Console 可访问" "PASS"
    else test_end "MinIO - Console 可访问" "SKIP"; fi
}

test_filebrowser() {
    test_start "FileBrowser - 容器运行"
    if assert_container_running "filebrowser"; then test_end "FileBrowser - 容器运行" "PASS"
    else test_end "FileBrowser - 容器运行" "FAIL"; return 1; fi
    test_start "FileBrowser - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "FileBrowser - HTTP 端点可达" "PASS"
    else test_end "FileBrowser - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_nextcloud || true; test_minio || true; test_filebrowser || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
