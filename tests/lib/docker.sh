#!/bin/bash
# =============================================================================
# Docker Utility Library — HomeLab Stack Integration Tests
# =============================================================================
# Description: Docker helper functions for container inspection and management
# Usage: source this library in test scripts
# Requirements: docker
# =============================================================================

# -----------------------------------------------------------------------------
# container_status — 获取容器状态
# Usage: status=$(container_status <name>)
# Returns: running | exited | paused | not_found
# -----------------------------------------------------------------------------
container_status() {
    local name="$1"
    docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found"
}

# -----------------------------------------------------------------------------
# container_health — 获取容器健康状态
# Usage: health=$(container_health <name>)
# Returns: healthy | unhealthy | starting | none (no healthcheck)
# -----------------------------------------------------------------------------
container_health() {
    local name="$1"
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "not_found"
}

# -----------------------------------------------------------------------------
# is_container_running — 检查容器是否运行
# Usage: is_container_running <name> && echo "running" || echo "stopped"
# -----------------------------------------------------------------------------
is_container_running() {
    local name="$1"
    [[ "$(container_status "$name")" == "running" ]]
}

# -----------------------------------------------------------------------------
# is_container_healthy — 检查容器是否健康
# Usage: is_container_healthy <name> && echo "healthy" || echo "unhealthy"
# -----------------------------------------------------------------------------
is_container_healthy() {
    local name="$1"
    [[ "$(container_health "$name")" == "healthy" ]]
}

# -----------------------------------------------------------------------------
# wait_for_healthy — 等待容器健康（最多timeout秒）
# Usage: wait_for_healthy <name> [timeout=60]
# Returns: 0=healthy, 1=not healthy
# -----------------------------------------------------------------------------
wait_for_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    local interval=2

    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(container_health "$name")
        case "$health" in
            healthy)
                return 0
                ;;
            unhealthy)
                return 1
                ;;
            none)
                # No healthcheck — check running state instead
                if is_container_running "$name"; then
                    return 0
                fi
                ;;
        esac
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 1
}

# -----------------------------------------------------------------------------
# get_container_ip — 获取容器IP
# Usage: ip=$(get_container_ip <name> [network])
# -----------------------------------------------------------------------------
get_container_ip() {
    local name="$1"
    local network="${2:-proxy}"
    docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" "$name" 2>/dev/null | awk '{print $1}'
}

# -----------------------------------------------------------------------------
# exec_in_container — 在容器内执行命令
# Usage: exec_in_container <name> <command...>
# Returns: command output
# -----------------------------------------------------------------------------
exec_in_container() {
    local name="$1"
    shift
    docker exec "$name" "$@"
}

# -----------------------------------------------------------------------------
# get_container_image — 获取容器使用的镜像
# Usage: image=$(get_container_image <name>)
# -----------------------------------------------------------------------------
get_container_image() {
    local name="$1"
    docker inspect -f '{{.Config.Image}}' "$name" 2>/dev/null
}

# -----------------------------------------------------------------------------
# is_docker_network_exists — 检查Docker网络是否存在
# Usage: is_docker_network_exists <network_name>
# -----------------------------------------------------------------------------
is_docker_network_exists() {
    local network="$1"
    docker network ls --format '{{.Name}}' | grep -q "^${network}$"
}

# -----------------------------------------------------------------------------
# wait_for_port — 等待TCP端口可访问
# Usage: wait_for_port <host> <port> [timeout=30]
# -----------------------------------------------------------------------------
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local elapsed=0
    local interval=1

    while [[ $elapsed -lt $timeout ]]; do
        if nc -z -w1 "$host" "$port" 2>/dev/null; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 1
}

# -----------------------------------------------------------------------------
# docker_compose_config — 验证compose文件语法
# Usage: docker_compose_config <compose_file>
# Returns: 0=config valid, 1=invalid
# -----------------------------------------------------------------------------
docker_compose_config() {
    local compose_file="$1"
    docker compose -f "$compose_file" config --quiet 2>/dev/null
}

# -----------------------------------------------------------------------------
# list_compose_files — 列出所有compose文件
# Usage: files=$(list_compose_files [dir=stacks])
# -----------------------------------------------------------------------------
list_compose_files() {
    local dir="${1:-stacks}"
    find "$dir" -maxdepth 2 -name 'docker-compose*.yml' -type f 2>/dev/null
}
