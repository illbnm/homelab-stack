#!/usr/bin/env bash
# productivity.test.sh - Productivity Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="productivity"

test_gitea() {
    test_start "Gitea - 容器运行"
    if assert_container_running "gitea"; then test_end "Gitea - 容器运行" "PASS"
    else test_end "Gitea - 容器运行" "FAIL"; return 1; fi
    test_start "Gitea - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3000/"; then test_end "Gitea - HTTP 端点可达" "PASS"
    else test_end "Gitea - HTTP 端点可达" "SKIP"; fi
}

test_vaultwarden() {
    test_start "Vaultwarden - 容器运行"
    if assert_container_running "vaultwarden"; then test_end "Vaultwarden - 容器运行" "PASS"
    else test_end "Vaultwarden - 容器运行" "FAIL"; return 1; fi
    test_start "Vaultwarden - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "Vaultwarden - HTTP 端点可达" "PASS"
    else test_end "Vaultwarden - HTTP 端点可达" "SKIP"; fi
}

test_outline() {
    test_start "Outline - 容器运行"
    if assert_container_running "outline"; then test_end "Outline - 容器运行" "PASS"
    else test_end "Outline - 容器运行" "FAIL"; return 1; fi
    test_start "Outline - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:3000/"; then test_end "Outline - HTTP 端点可达" "PASS"
    else test_end "Outline - HTTP 端点可达" "SKIP"; fi
}

test_bookstack() {
    test_start "BookStack - 容器运行"
    if assert_container_running "bookstack"; then test_end "BookStack - 容器运行" "PASS"
    else test_end "BookStack - 容器运行" "FAIL"; return 1; fi
    test_start "BookStack - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:6875/"; then test_end "BookStack - HTTP 端点可达" "PASS"
    else test_end "BookStack - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_gitea || true; test_vaultwarden || true; test_outline || true; test_bookstack || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
