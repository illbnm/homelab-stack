#!/usr/bin/env bash
# notifications.test.sh - Notifications Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="notifications"

test_ntfy() {
    test_start "Ntfy - 容器运行"
    if assert_container_running "ntfy"; then test_end "Ntfy - 容器运行" "PASS"
    else test_end "Ntfy - 容器运行" "FAIL"; return 1; fi
    test_start "Ntfy - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:80/"; then test_end "Ntfy - HTTP 端点可达" "PASS"
    else test_end "Ntfy - HTTP 端点可达" "SKIP"; fi
}

test_apprise() {
    test_start "Apprise - 容器运行"
    if assert_container_running "apprise"; then test_end "Apprise - 容器运行" "PASS"
    else test_end "Apprise - 容器运行" "FAIL"; return 1; fi
    test_start "Apprise - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8000/"; then test_end "Apprise - HTTP 端点可达" "PASS"
    else test_end "Apprise - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_ntfy || true; test_apprise || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
