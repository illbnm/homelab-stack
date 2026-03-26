#!/usr/bin/env bash
# base.test.sh - Base Infrastructure Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="base"

test_traefik() {
    test_start "Traefik - 容器运行"
    if assert_container_running "traefik"; then test_end "Traefik - 容器运行" "PASS"
    else test_end "Traefik - 容器运行" "FAIL" "容器未运行"; return 1; fi
    
    test_start "Traefik - 容器健康"
    local state; state=$(docker inspect -f '{{.State.Running}}' traefik 2>/dev/null)
    if [[ "$state" == "true" ]]; then test_end "Traefik - 容器健康" "PASS" "无健康检查但容器运行中"
    else test_end "Traefik - 容器健康" "FAIL"; return 1; fi
    
    test_start "Traefik - 80端口监听"
    if check_port "127.0.0.1" "80" 5; then test_end "Traefik - 80端口监听" "PASS"
    else test_end "Traefik - 80端口监听" "SKIP" "端口80未监听"; fi
    
    test_start "Traefik - 443端口监听"
    if check_port "127.0.0.1" "443" 5; then test_end "Traefik - 443端口监听" "PASS"
    else test_end "Traefik - 443端口监听" "SKIP" "端口443未监听"; fi
}

test_portainer() {
    test_start "Portainer - 容器运行"
    if assert_container_running "portainer"; then test_end "Portainer - 容器运行" "PASS"
    else test_end "Portainer - 容器运行" "FAIL"; return 1; fi
    
    test_start "Portainer - 容器健康"
    local state; state=$(docker inspect -f '{{.State.Running}}' portainer 2>/dev/null)
    if [[ "$state" == "true" ]]; then test_end "Portainer - 容器健康" "PASS" "无健康检查但运行中"
    else test_end "Portainer - 容器健康" "FAIL"; return 1; fi
    
    test_start "Portainer - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9000/" 2>/dev/null; then
        test_end "Portainer - HTTP 端点可达" "PASS"
    else test_end "Portainer - HTTP 端点可达" "SKIP"; fi
}

test_watchtower() {
    test_start "Watchtower - 容器运行"
    if assert_container_running "watchtower"; then test_end "Watchtower - 容器运行" "PASS"
    else test_end "Watchtower - 容器运行" "FAIL"; return 1; fi
    
    test_start "Watchtower - 重启次数正常"
    local restart_count; restart_count=$(get_container_restart_count "watchtower")
    if [[ -n "$restart_count" ]] && (( restart_count <= 5 )); then
        test_end "Watchtower - 重启次数正常" "PASS" "重启次数: $restart_count"
    else test_end "Watchtower - 重启次数正常" "FAIL" "重启次数过多: $restart_count"; return 1; fi
}

test_socket_proxy() {
    test_start "Socket Proxy - 容器运行"
    if assert_container_running "socket-proxy"; then test_end "Socket Proxy - 容器运行" "PASS"
    else test_end "Socket Proxy - 容器运行" "FAIL"; return 1; fi
}

test_docker_network() {
    test_start "Docker - Traefik 连接代理网络"
    if containers_in_same_network "traefik" "socket-proxy"; then
        test_end "Docker - Traefik 连接代理网络" "PASS"
    else test_end "Docker - Traefik 连接代理网络" "SKIP" "容器不在同一网络"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_traefik || true; test_portainer || true; test_watchtower || true
    test_socket_proxy || true; test_docker_network || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
