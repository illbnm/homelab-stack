#!/bin/bash
# base.test.sh - Base Infrastructure 栈测试
# 测试 Traefik, Portainer, Watchtower

set -u

# Traefik 测试
test_traefik_running() {
    assert_container_running "traefik"
}

test_traefik_health() {
    assert_container_healthy "traefik" 60
}

test_traefik_dashboard() {
    assert_http_200 "http://localhost:8080/api/version"
}

test_traefik_ping() {
    assert_http_response "http://localhost:8080/ping" "pong" "Traefik ping endpoint"
}

# Portainer 测试
test_portainer_running() {
    assert_container_running "portainer"
}

test_portainer_http() {
    assert_http_200 "http://localhost:9000"
}

test_portainer_api() {
    assert_http_response "http://localhost:9000/api/status" "version" "Portainer API status"
}

# Watchtower 测试
test_watchtower_running() {
    assert_container_running "watchtower"
}

test_watchtower_health() {
    # Watchtower 可能没有 healthcheck，检查容器运行即可
    local status=$(docker inspect --format='{{.State.Status}}' "watchtower" 2>/dev/null)
    if [[ "$status" == "running" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "watchtower running" "$duration"
        return 0
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "watchtower running" "$duration" "Container status: ${status:-not found}"
        return 1
    fi
}

# Compose 语法测试
test_compose_syntax_base() {
    local compose_file="${ROOT_DIR}/stacks/base/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_valid "$compose_file"
    else
        # 如果文件不存在，跳过
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "Compose valid: $compose_file" "$duration"
    fi
}

# 检查无 latest 标签
test_no_latest_tags_base() {
    local stacks_dir="${ROOT_DIR}/stacks/base"
    if [[ -d "$stacks_dir" ]]; then
        assert_no_latest_images "$stacks_dir"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "No :latest tags in $stacks_dir" "$duration"
    fi
}

# Socket Proxy 测试 (如果存在)
test_socket_proxy_running() {
    if container_exists "socket-proxy"; then
        assert_container_running "socket-proxy"
    fi
}

# 网络测试
test_base_network() {
    # 检查 proxy 网络是否存在
    if docker network inspect proxy &> /dev/null; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "proxy network exists" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "proxy network exists" "$duration"
    fi
}
