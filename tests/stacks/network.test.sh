#!/usr/bin/env bash
# network.test.sh - Network Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="network"

test_adguard() {
    test_start "AdGuard Home - 容器运行"
    if assert_container_running "adguardhome"; then test_end "AdGuard Home - 容器运行" "PASS"
    else test_end "AdGuard Home - 容器运行" "FAIL"; return 1; fi
    test_start "AdGuard Home - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:3000/"; then test_end "AdGuard Home - HTTP 端点可达" "PASS"
    else test_end "AdGuard Home - HTTP 端点可达" "SKIP"; fi
}

test_nginx_proxy_manager() {
    test_start "Nginx Proxy Manager - 容器运行"
    if assert_container_running "nginx-proxy-manager"; then test_end "Nginx Proxy Manager - 容器运行" "PASS"
    else test_end "Nginx Proxy Manager - 容器运行" "FAIL"; return 1; fi
    test_start "Nginx Proxy Manager - Admin UI"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:81/"; then test_end "Nginx Proxy Manager - Admin UI" "PASS"
    else test_end "Nginx Proxy Manager - Admin UI" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_adguard || true; test_nginx_proxy_manager || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
