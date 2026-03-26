#!/usr/bin/env bash
# =============================================================================
# docker.sh - HomeLab Stack Docker 工具函数库
# =============================================================================
# 功能：封装 Docker CLI 操作，提供容器管理、镜像检查、网络查询等通用功能
# 依赖：docker, docker compose cli (v2+)
#
# 使用示例:
#   source tests/lib/docker.sh
#   wait_for_service "traefik" --timeout 60
#   list_containers_by_stack "media"
# =============================================================================

set -uo pipefail

# Docker 命令别名（便于未来扩展）
DOCKER_CMD="docker"
COMPOSE_CMD="docker compose"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# 容器管理函数
# =============================================================================

# 检查容器是否正在运行
# 用法：is_container_running <container_name>
# 返回：0=运行中，1=未运行
is_container_running() {
    local container_name=$1
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# 获取容器状态
# 用法：get_container_status <container_name>
# 返回：running/stopped/health/unhealthy/none
get_container_status() {
    local container_name=$1
    docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "none"
}

# 获取容器健康状态
# 用法：get_container_health <container_name>
# 返回：healthy/unhealthy/no-healthcheck/none
get_container_health() {
    local container_name=$1
    docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none"
}

# 等待容器健康（轮询模式）
# 用法：wait_for_container <container_name> [timeout=60] [interval=2]
# 返回：0=健康，1=超时或异常
wait_for_container() {
    local container_name=$1
    local timeout=${2:-60}
    local interval=${3:-2}
    local waited=0

    while [[ $waited -lt $timeout ]]; do
        local status
        status=$(get_container_status "$container_name")
        
        if [[ "$status" == "running" ]]; then
            local health
            health=$(get_container_health "$container_name")
            
            if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
                echo -e "${GREEN}✓${NC} Container '$container_name' is running"
                return 0
            fi
        fi
        
        sleep "$interval"
        ((waited += interval)) || true
    done
    
    echo -e "${RED}✗${NC} Timeout waiting for container '$container_name'" >&2
    return 1
}

# =============================================================================
# Docker Compose 函数
# =============================================================================

# 检查 Compose 文件是否存在且有效
# 用法：validate_compose_file <compose_file>
# 返回：0=有效，1=无效/不存在
validate_compose_file() {
    local compose_file=$1
    
    if [[ ! -f "$compose_file" ]]; then
        echo -e "${RED}✗${NC} Compose file not found: $compose_file" >&2
        return 1
    fi
    
    if ! docker compose -f "$compose_file" config --quiet >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Invalid Compose syntax: $compose_file" >&2
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Valid Compose file: $compose_file"
    return 0
}

# 列出某个 Stack 的所有容器
# 用法：list_containers_by_stack <stack_name> [stacks_dir=stacks]
# 返回：容器列表（每行一个）
list_containers_by_stack() {
    local stack_name=$1
    local stacks_dir=${2:-stacks}
    local compose_file="$stacks_dir/$stack_name/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        docker compose -f "$compose_file" ps --format '{{.Name}}' 2>/dev/null || echo ""
    else
        echo "Stack not found: $stack_name" >&2
        return 1
    fi
}

# 启动 Stack（带健康等待）
# 用法：start_stack <stack_name> [timeout=300]
# 返回：0=成功，1=失败
start_stack() {
    local stack_name=$1
    local timeout=${2:-300}
    
    echo -e "${BLUE}▶${NC} Starting stack: $stack_name" >&2
    
    if ! docker compose -f "stacks/$stack_name/docker-compose.yml" up -d; then
        echo -e "${RED}✗${NC} Failed to start stack: $stack_name" >&2
        return 1
    fi
    
    # 等待所有容器健康
    local containers
    containers=$(list_containers_by_stack "$stack_name")
    
    for container in $containers; do
        if ! wait_for_container "$container" --timeout "$timeout"; then
            echo -e "${YELLOW}⚠${NC} Some containers may not be healthy yet" >&2
        fi
    done
    
    echo -e "${GREEN}✓${NC} Stack '$stack_name' started successfully"
    return 0
}

# 停止并清理 Stack
# 用法：stop_stack <stack_name> [remove_volumes=false]
# 返回：0=成功，1=失败
stop_stack() {
    local stack_name=$1
    local remove_volumes=${2:-false}
    
    echo -e "${BLUE}▶${NC} Stopping stack: $stack_name" >&2
    
    if [[ "$remove_volumes" == "true" ]]; then
        docker compose -f "stacks/$stack_name/docker-compose.yml" down --volumes
    else
        docker compose -f "stacks/$stack_name/docker-compose.yml" down
    fi
    
    echo -e "${GREEN}✓${NC} Stack '$stack_name' stopped"
    return 0
}

# =============================================================================
# 镜像管理函数
# =============================================================================

# 检查镜像是否已拉取
# 用法：is_image_pulled <image_name>
# 返回：0=已拉取，1=未拉取
is_image_pulled() {
    local image_name=$1
    docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q "^${image_name}$"
}

# 列出所有正在使用的镜像
# 用法：list_used_images [stacks_dir=stacks]
# 返回：镜像列表（每行一个）
list_used_images() {
    local stacks_dir=${1:-stacks}
    
    find "$stacks_dir" -name 'docker-compose*.yml' -exec grep -h '^ *image:' {} \; 2>/dev/null | \
        sed 's/^ *image: *//' | sort -u || echo ""
}

# 检查是否有 :latest 标签的镜像（不推荐）
# 用法：check_latest_tags [stacks_dir=stacks]
# 返回：发现的数量
check_latest_tags() {
    local stacks_dir=${1:-stacks}
    
    grep -r 'image:.*:latest' "$stacks_dir" --include='docker-compose*.yml' 2>/dev/null | wc -l || echo "0"
}

# =============================================================================
# 网络查询函数
# =============================================================================

# 获取容器的 IP 地址（在指定网络中）
# 用法：get_container_ip <container_name> [network=proxy]
# 返回：IP 地址或空字符串
get_container_ip() {
    local container_name=$1
    local network=${2:-bridge}
    
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null || echo ""
}

# 检查两个容器是否在同一网络中
# 用法：containers_share_network <container1> <container2> [network=proxy]
# 返回：0=是，1=否
containers_share_network() {
    local container1=$1
    local container2=$2
    local network=${3:-bridge}
    
    local ip1 ip2
    ip1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container1" 2>/dev/null)
    ip2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container2" 2>/dev/null)
    
    if [[ -n "$ip1" ]] && [[ -n "$ip2" ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# 日志和调试函数
# =============================================================================

# 获取容器最近 N 行日志
# 用法：get_container_logs <container_name> [lines=50]
# 返回：日志内容
get_container_logs() {
    local container_name=$1
    local lines=${2:-50}
    
    docker logs --tail "$lines" "$container_name" 2>/dev/null || echo "No logs available"
}

# 检查端口是否被容器监听
# 用法：is_port_exposed <container_name> <port>
# 返回：0=暴露，1=未暴露
is_port_exposed() {
    local container_name=$1
    local port=$2
    
    docker inspect -f '{{range .NetworkSettings.Ports}}{{.HostPort}}{{end}}' "$container_name" 2>/dev/null | \
        grep -q "^${port}$"
}

# =============================================================================
# 批量操作函数
# =============================================================================

# 批量等待多个容器健康
# 用法：wait_for_all_containers <container1> <container2> ... [timeout=60]
# 返回：成功的数量/总数
wait_for_all_containers() {
    local timeout=${!#:-60}
    shift
    local containers=("$@")
    
    local success=0
    local total=${#containers[@]}
    
    for container in "${containers[@]}"; do
        if wait_for_container "$container" --timeout "$timeout"; then
            ((success++)) || true
        fi
    done
    
    echo -e "${GREEN}✓${NC} $success/$total containers healthy"
    return 0
}

# =============================================================================
# 工具函数
# =============================================================================

# 检查 Docker CLI 是否可用
check_docker_available() {
    if ! command -v docker &>/dev/null; then
        echo "Docker not installed!" >&2
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo "Docker daemon is not running or not accessible" >&2
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Docker is available"
    return 0
}

# 检查 Docker Compose v2 是否可用
check_compose_available() {
    if ! docker compose version &>/dev/null; then
        echo "Docker Compose v2 not found!" >&2
        return 1
    fi
    
    local version
    version=$(docker compose version --short)
    echo -e "${GREEN}✓${NC} Docker Compose v2: $version"
    return 0
}
