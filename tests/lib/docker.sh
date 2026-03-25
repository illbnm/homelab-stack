#!/bin/bash
# docker.sh - Docker 工具函数 for HomeLab Stack 集成测试

set -u

# 检查 Docker 是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "❌ Docker daemon not running"
        return 1
    fi
    
    return 0
}

# 检查 Docker Compose 是否可用
check_docker_compose() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found"
        return 1
    fi
    
    if ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose not found (need v2)"
        return 1
    fi
    
    return 0
}

# 获取容器 IP 地址
get_container_ip() {
    local container="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null
}

# 检查容器是否存在
container_exists() {
    local container="$1"
    docker inspect "$container" &> /dev/null
}

# 检查容器是否运行
container_running() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    [[ "$status" == "running" ]]
}

# 等待容器健康 (最多等待指定秒数)
wait_container_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local start=$(date +%s)
    
    while true; do
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        
        if [[ "$status" != "running" ]]; then
            return 1
        fi
        
        if [[ "$health" == "healthy" || "$health" == "none" ]]; then
            return 0
        fi
        
        local now=$(date +%s)
        local elapsed=$((now - start))
        if [[ $elapsed -ge $timeout ]]; then
            return 1
        fi
        
        sleep 2
    done
}

# 获取容器日志 (最后 N 行)
get_container_logs() {
    local container="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$container" 2>&1
}

# 重启容器
restart_container() {
    local container="$1"
    docker restart "$container" &> /dev/null
}

# 停止容器
stop_container() {
    local container="$1"
    docker stop "$container" &> /dev/null
}

# 启动容器
start_container() {
    local container="$1"
    docker start "$container" &> /dev/null
}

# 列出所有运行中的容器
list_running_containers() {
    docker ps --format '{{.Names}}'
}

# 检查端口是否被监听
check_port_listening() {
    local port="$1"
    local host="${2:-localhost}"
    
    if command -v nc &> /dev/null; then
        nc -z "$host" "$port" &> /dev/null
        return $?
    elif command -v bash &> /dev/null; then
        (echo > /dev/tcp/"$host"/"$port") 2>/dev/null
        return $?
    else
        curl -s --connect-timeout 2 "$host:$port" &> /dev/null
        return $?
    fi
}

# 执行容器内命令
exec_in_container() {
    local container="$1"
    shift
    docker exec "$container" "$@" 2>&1
}

# 获取容器环境变量
get_container_env() {
    local container="$1"
    local var="$2"
    docker exec "$container" printenv "$var" 2>/dev/null
}

# 检查 Docker 网络是否存在
network_exists() {
    local network="$1"
    docker network inspect "$network" &> /dev/null
}

# 创建 Docker 网络 (如果不存在)
ensure_network() {
    local network="$1"
    if ! network_exists "$network"; then
        docker network create "$network" &> /dev/null
    fi
}

# 清理未使用的容器、网络、镜像
docker_cleanup() {
    docker container prune -f &> /dev/null
    docker network prune -f &> /dev/null
    # 不自动清理镜像，避免影响其他项目
}

# 获取 Docker 版本
get_docker_version() {
    docker --version | cut -d' ' -f3 | cut -d',' -f1
}

# 获取 Docker Compose 版本
get_compose_version() {
    docker compose version --short 2>/dev/null || docker-compose version --short 2>/dev/null
}
