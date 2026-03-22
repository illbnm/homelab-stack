#!/bin/bash
# docker.sh - Docker 工具函数 for HomeLab Stack Integration Tests

set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# check_docker - 检查 Docker 是否可用
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        return 1
    fi
    
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        return 1
    fi
    
    return 0
}

# check_docker_compose - 检查 Docker Compose 是否可用
check_docker_compose() {
    if command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
        return 0
    elif docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
        return 0
    else
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        return 1
    fi
}

# wait_container_running - 等待容器启动
# 用法: wait_container_running <container_name> [timeout]
wait_container_running() {
    local name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local status
        status=$(docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null)
        
        if [[ "$status" == "true" ]]; then
            return 0
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    echo -e "${RED}Timeout waiting for container '$name' to start${NC}"
    return 1
}

# wait_container_healthy - 等待容器健康
# 用法: wait_container_healthy <container_name> [timeout]
wait_container_healthy() {
    local name="$1"
    local timeout="${2:-120}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)
        
        if [[ "$health" == "healthy" ]]; then
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            echo -e "${RED}Container '$name' is unhealthy${NC}"
            return 1
        elif [[ "$health" == "none" ]]; then
            # 没有 healthcheck，检查是否运行
            local running
            running=$(docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null)
            if [[ "$running" == "true" ]]; then
                return 0
            fi
        fi
        
        sleep 2
        ((elapsed+=2))
    done
    
    echo -e "${RED}Timeout waiting for container '$name' to be healthy${NC}"
    return 1
}

# get_container_port - 获取容器映射端口
# 用法: get_container_port <container_name> <container_port>
get_container_port() {
    local name="$1"
    local container_port="$2"
    
    docker port "$name" "$container_port" 2>/dev/null | cut -d: -f2
}

# exec_in_container - 在容器内执行命令
# 用法: exec_in_container <container_name> <command>
exec_in_container() {
    local name="$1"
    shift
    docker exec "$name" "$@"
}

# get_container_logs - 获取容器日志
# 用法: get_container_logs <container_name> [lines]
get_container_logs() {
    local name="$1"
    local lines="${2:-100}"
    
    docker logs --tail "$lines" "$name" 2>&1
}

# stop_all_containers - 停止所有相关容器
# 用法: stop_all_containers [compose_file]
stop_all_containers() {
    local compose_file="${1:-}"
    
    if [[ -n "$compose_file" && -f "$compose_file" ]]; then
        $COMPOSE_CMD -f "$compose_file" down 2>/dev/null
    else
        docker stop $(docker ps -q --filter "name=homelab") 2>/dev/null
    fi
}

# get_stack_containers - 获取栈的所有容器名称
# 用法: get_stack_containers <compose_file>
get_stack_containers() {
    local compose_file="$1"
    
    $COMPOSE_CMD -f "$compose_file" ps --services 2>/dev/null
}

# check_port_open - 检查端口是否开放
# 用法: check_port_open <host> <port> [timeout]
check_port_open() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
    return $?
}
