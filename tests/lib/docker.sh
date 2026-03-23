#!/usr/bin/env bash
# docker.sh - Docker 操作工具库
# 提供常用的 Docker 测试辅助函数

set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 Docker 是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误：Docker 未安装${NC}"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}错误：Docker 守护进程未运行${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Docker 可用${NC}"
    return 0
}

# 检查 docker-compose 是否可用
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ docker-compose 可用${NC}"
        return 0
    elif docker compose version &> /dev/null; then
        echo -e "${GREEN}✓ docker compose (v2) 可用${NC}"
        return 0
    else
        echo -e "${YELLOW}警告：docker-compose 不可用${NC}"
        return 1
    fi
}

# 运行 docker-compose 命令 (兼容 v1 和 v2)
docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

# 等待容器就绪
wait_for_container() {
    local container="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    
    echo -e "${BLUE}等待容器就绪：$container (最多 ${timeout}s)${NC}"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
            local status
            status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "running")
            
            if [[ "$status" == "healthy" ]] || [[ "$status" == "running" ]]; then
                echo -e "${GREEN}✓ 容器已就绪：$container${NC}"
                return 0
            fi
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    echo -e "${RED}✗ 容器就绪超时：$container${NC}"
    return 1
}

# 等待端口就绪
wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"
    local timeout="${3:-30}"
    local interval="${4:-2}"
    
    echo -e "${BLUE}等待端口就绪：$host:$port (最多 ${timeout}s)${NC}"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if nc -z "$host" "$port" 2>/dev/null || \
           curl -s -o /dev/null "http://$host:$port" 2>/dev/null || \
           bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "${GREEN}✓ 端口已就绪：$host:$port${NC}"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    echo -e "${RED}✗ 端口就绪超时：$host:$port${NC}"
    return 1
}

# 获取容器日志
get_container_logs() {
    local container="$1"
    local lines="${2:-100}"
    
    docker logs --tail "$lines" "$container" 2>&1
}

# 检查容器健康状态
check_container_health() {
    local container="$1"
    
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)
    
    if [[ "$health" == "healthy" ]]; then
        echo -e "${GREEN}✓ 健康：$container${NC}"
        return 0
    elif [[ "$health" == "unhealthy" ]]; then
        echo -e "${RED}✗ 不健康：$container${NC}"
        return 1
    else
        echo -e "${YELLOW}○ 无健康检查：$container${NC}"
        return 0
    fi
}

# 清理容器
cleanup_containers() {
    local pattern="$1"
    
    echo -e "${BLUE}清理容器：$pattern${NC}"
    docker ps -a --filter "name=$pattern" --format '{{.Names}}' | while read -r container; do
        docker rm -f "$container" 2>/dev/null && \
            echo -e "${GREEN}✓ 已删除：$container${NC}"
    done
}

# 清理网络
cleanup_networks() {
    local pattern="$1"
    
    echo -e "${BLUE}清理网络：$pattern${NC}"
    docker network ls --filter "name=$pattern" --format '{{.Name}}' | while read -r network; do
        docker network rm "$network" 2>/dev/null && \
            echo -e "${GREEN}✓ 已删除：$network${NC}"
    done
}

# 清理卷
cleanup_volumes() {
    local pattern="$1"
    
    echo -e "${BLUE}清理卷：$pattern${NC}"
    docker volume ls --filter "name=$pattern" --format '{{.Name}}' | while read -r volume; do
        docker volume rm "$volume" 2>/dev/null && \
            echo -e "${GREEN}✓ 已删除：$volume${NC}"
    done
}
