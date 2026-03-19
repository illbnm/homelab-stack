#!/bin/bash
# docker.sh - Docker 工具函数 for HomeLab Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/assert.sh"

# 检查容器是否运行
check_container_running() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    [[ "$status" == "running" ]]
}

# 检查容器健康状态
check_container_healthy() {
    local container="$1"
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    [[ "$health" == "healthy" ]]
}

# 等待容器健康（最多等待指定秒数）
wait_container_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if check_container_healthy "$container"; then
            return 0
        fi
        sleep 5
        ((elapsed+=5))
    done
    return 1
}

# 检查 HTTP 端点是否返回 200
check_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    [[ "$http_code" == "200" ]]
}

# 检查 HTTP 响应是否包含指定模式
check_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    echo "$response" | grep -q "$pattern"
}

# 检查 JSON 值是否匹配
check_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    [[ "$actual" == "$expected" ]]
}

# 检查 JSON 键是否存在
check_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local result=$(echo "$json" | jq "$jq_path" 2>/dev/null)
    [[ "$result" != "null" && -n "$result" ]]
}

# 检查 JSON 是否没有错误
check_no_errors() {
    local json="$1"
    local errors=$(echo "$json" | jq '.errors' 2>/dev/null)
    [[ "$errors" == "null" || "$errors" == "[]" || -z "$errors" ]]
}

# 检查文件是否包含指定模式
check_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" 2>/dev/null
}

# 检查目录中没有 :latest 镜像标签
check_no_latest_images() {
    local dir="$1"
    local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    [[ "$count" -eq 0 ]]
}

# 验证 docker-compose 文件语法
validate_compose_syntax() {
    local file="$1"
    docker compose -f "$file" config --quiet 2>&1
    return $?
}

# 获取容器日志
get_container_logs() {
    local container="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$container" 2>&1
}

# 重启容器
restart_container() {
    local container="$1"
    docker restart "$container" 2>/dev/null
}

# 停止容器
stop_container() {
    local container="$1"
    docker stop "$container" 2>/dev/null
}

# 启动容器
start_container() {
    local container="$1"
    docker start "$container" 2>/dev/null
}

# 导出所有函数
export -f check_container_running check_container_healthy wait_container_healthy
export -f check_http_200 check_http_response check_json_value check_json_key_exists
export -f check_no_errors check_file_contains check_no_latest_images
export -f validate_compose_syntax get_container_logs restart_container stop_container start_container
