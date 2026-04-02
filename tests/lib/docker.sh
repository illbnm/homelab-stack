#!/usr/bin/env bash
# Docker工具函数 - HomeLab Stack Integration Tests

set -euo pipefail

# 等待容器健康
wait_for_healthy() {
    local container_name="$1"
    local timeout="${2:-60}"

    echo "等待容器 $container_name 健康..."
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if docker ps --filter "name=$container_name" --filter "health=healthy" | grep -q "$container_name"; then
            echo "✅ 容器 $container_name 已健康 (耗时 ${elapsed}s)"
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done

    echo "❌ 容器 $container_name 健康检查超时"
    return 1
}

# 获取容器状态
get_container_status() {
    local container_name="$1"
    docker ps -a --filter "name=$container_name" --format "{{.Status}}"
}

# 获取容器IP
get_container_ip() {
    local container_name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null
}

# 检查容器是否存在
container_exists() {
    local container_name="$1"
    docker ps -a --filter "name=$container_name" | grep -q "$container_name"
}

# 检查容器是否运行
container_running() {
    local container_name="$1"
    docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"
}

# 获取容器日志
get_container_logs() {
    local container_name="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$container_name" 2>&1
}

# 重启容器
restart_container() {
    local container_name="$1"
    echo "重启容器 $container_name..."
    docker restart "$container_name"
}

# 停止容器
stop_container() {
    local container_name="$1"
    echo "停止容器 $container_name..."
    docker stop "$container_name" 2>/dev/null || true
}

# 启动容器
start_container() {
    local container_name="$1"
    echo "启动容器 $container_name..."
    docker start "$container_name"
}

# 清理所有容器
cleanup_containers() {
    local stack_name="$1"
    echo "清理 $stack_name 栈的所有容器..."
    docker compose -f "stacks/$stack_name/docker-compose.yml" down -v --remove-orphans
}

# 获取compose项目容器列表
get_stack_containers() {
    local stack_name="$1"
    docker compose -f "stacks/$stack_name/docker-compose.yml" ps -q
}

# 等待所有容器健康
wait_all_healthy() {
    local stack_name="$1"
    local timeout="${2:-120}"

    echo "等待 $stack_name 栈所有容器健康..."

    local containers
    containers=$(docker compose -f "stacks/$stack_name/docker-compose.yml" ps --services)

    for service in $containers; do
        if ! wait_for_healthy "${stack_name}-${service}-1" "$timeout"; then
            return 1
        fi
    done

    return 0
}
