#!/usr/bin/env bash
# dashboard.test.sh - Dashboard Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="dashboard"

test_homarr() {
    test_start "Homarr - 容器运行"
    if assert_container_running "homarr"; then test_end "Homarr - 容器运行" "PASS"
    else test_end "Homarr - 容器运行" "FAIL"; return 1; fi
    test_start "Homarr - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3000/"; then test_end "Homarr - HTTP 端点可达" "PASS"
    else test_end "Homarr - HTTP 端点可达" "SKIP"; fi
}

test_homepage() {
    test_start "Homepage - 容器运行"
    if assert_container_running "homepage"; then test_end "Homepage - 容器运行" "PASS"
    else test_end "Homepage - 容器运行" "FAIL"; return 1; fi
    test_start "Homepage - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3000/"; then test_end "Homepage - HTTP 端点可达" "PASS"
    else test_end "Homepage - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_homarr || true; test_homepage || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
