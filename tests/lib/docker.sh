#!/usr/bin/env bash
# =============================================================================
# docker.sh - Docker 工具函数库 for HomeLab Stack Integration Tests
# =============================================================================

# 颜色定义
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_RESET='\033[0m'

# -----------------------------------------------------------------------------
# 基础 Docker 信息
# -----------------------------------------------------------------------------
docker_available() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        return 0
    else
        return 1
    fi
}

get_docker_version() {
    docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown"
}

get_docker_compose_version() {
    docker compose version --format '{{.Version}}' 2>/dev/null || echo "unknown"
}

docker_network_exists() {
    local network_name="$1"
    docker network ls --format '{{.Name}}' | grep -q "^${network_name}$"
}

docker_network_ensure() {
    local network_name="$1"
    local driver="${2:-bridge}"
    if ! docker_network_exists "$network_name"; then
        docker network create "$network_name" --driver "$driver" 2>/dev/null
        return $?
    fi
    return 0
}

list_containers() {
    local filter="${1:-name}"
    local value="${2:-}"
    if [[ -z "$value" ]]; then
        docker ps -a --format '{{.Names}}'
    else
        case "$filter" in
            name)
                docker ps -a --filter "name=$value" --format '{{.Names}}'
                ;;
            status)
                docker ps -a --filter "status=$value" --format '{{.Names}}'
                ;;
            network)
                docker ps -a --filter "network=$value" --format '{{.Names}}'
                ;;
        esac
    fi
}

list_running_containers() {
    docker ps --format '{{.Names}}'
}

list_stopped_containers() {
    docker ps -a --filter "status=exited" --format '{{.Names}}'
}

# -----------------------------------------------------------------------------
# 容器信息查询
# -----------------------------------------------------------------------------
get_container_state() {
    local container_name="$1"
    docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null
}

is_container_running() {
    local container_name="$1"
    [[ "$(get_container_state "$container_name")" == "running" ]]
}

get_container_exit_code() {
    local container_name="$1"
    docker inspect -f '{{.State.ExitCode}}' "$container_name" 2>/dev/null
}

get_container_restart_count() {
    local container_name="$1"
    docker inspect -f '{{.RestartCount}}' "$container_name" 2>/dev/null
}

get_container_created() {
    local container_name="$1"
    docker inspect -f '{{.Created}}' "$container_name" 2>/dev/null
}

get_container_started() {
    local container_name="$1"
    docker inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null
}

get_container_uptime() {
    local container_name="$1"
    local started_at
    started_at=$(docker inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null)
    if [[ -z "$started_at" ]] || [[ "$started_at" == "<no value>" ]]; then
        echo "0"
        return
    fi
    local started_ts
    started_ts=$(date -d "$started_at" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    echo $((now_ts - started_ts))
}

get_container_image() {
    local container_name="$1"
    docker inspect -f '{{.Config.Image}}' "$container_name" 2>/dev/null
}

get_container_log_size() {
    local container_name="$1"
    docker inspect -f '{{.SizeRootFs}}' "$container_name" 2>/dev/null || echo "0"
}

get_container_ports() {
    local container_name="$1"
    docker inspect -f '{{range $k, $v := .NetworkSettings.Ports}}{{$k}} -> {{range $v}}{{.HostPort}}{{end}} {{end}}' "$container_name" 2>/dev/null
}

# -----------------------------------------------------------------------------
# 容器网络信息
# -----------------------------------------------------------------------------
get_container_ip_address() {
    local container_name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null | head -1
}

get_container_networks() {
    local container_name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' "$container_name" 2>/dev/null
}

get_container_hostname() {
    local container_name="$1"
    docker inspect -f '{{.Config.Hostname}}' "$container_name" 2>/dev/null
}

can_container_resolve() {
    local container_name="$1"
    local domain="${2:-google.com}"
    docker exec "$container_name" nslookup "$domain" &>/dev/null || \
    docker exec "$container_name" getent hosts "$domain" &>/dev/null
}

can_container_connect() {
    local container1="$1"
    local container2="$2"
    local port="${3:-80}"
    local ip1 ip2
    ip1=$(get_container_ip_address "$container1")
    ip2=$(get_container_ip_address "$container2")
    if [[ -z "$ip1" ]] || [[ -z "$ip2" ]]; then
        return 1
    fi
    docker exec "$container1" nc -z -w 5 "$ip2" "$port" 2>/dev/null
}

# -----------------------------------------------------------------------------
# 容器资源使用
# -----------------------------------------------------------------------------
get_container_cpu_percent() {
    local container_name="$1"
    docker stats --no-stream --format '{{.CPUPerc}}' "$container_name" 2>/dev/null | tr -d '%'
}

get_container_memory_usage() {
    local container_name="$1"
    docker stats --no-stream --format '{{.MemUsage}}' "$container_name" 2>/dev/null
}

get_container_memory_percent() {
    local container_name="$1"
    docker stats --no-stream --format '{{.MemPerc}}' "$container_name" 2>/dev/null | tr -d '%'
}

get_container_network_io() {
    local container_name="$1"
    docker stats --no-stream --format '{{.NetIO}}' "$container_name" 2>/dev/null
}

get_container_block_io() {
    local container_name="$1"
    docker stats --no-stream --format '{{.BlockIO}}' "$container_name" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Docker Compose 辅助函数
# -----------------------------------------------------------------------------
compose_file_exists() {
    local compose_file="$1"
    [[ -f "$compose_file" ]]
}

get_compose_service_state() {
    local compose_file="$1"
    local service_name="$2"
    docker compose -f "$compose_file" ps --format json 2>/dev/null | \
        jq -r ".[] | select(.Service == \"$service_name\") | .State" 2>/dev/null
}

get_compose_services_state() {
    local compose_file="$1"
    docker compose -f "$compose_file" ps --format json 2>/dev/null | jq -r '.[] | "\(.Service)=\(.State)"' 2>/dev/null
}

is_compose_service_running() {
    local compose_file="$1"
    local service_name="$2"
    [[ "$(get_compose_service_state "$compose_file" "$service_name")" == "running" ]]
}

wait_compose_service() {
    local compose_file="$1"
    local service_name="$2"
    local timeout="${3:-120}"
    local interval="${4:-5}"
    local elapsed=0
    while (( elapsed < timeout )); do
        if is_compose_service_running "$compose_file" "$service_name"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    return 1
}

get_compose_service_health() {
    local compose_file="$1"
    local service_name="$2"
    docker compose -f "$compose_file" ps --format json 2>/dev/null | \
        jq -r ".[] | select(.Service == \"$service_name\") | .Health" 2>/dev/null
}

# -----------------------------------------------------------------------------
# 镜像操作
# -----------------------------------------------------------------------------
image_exists() {
    local image_name="$1"
    docker image ls "$image_name" --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q "$image_name"
}

get_image_size() {
    local image_name="$1"
    docker image ls "$image_name" --format '{{.Size}}' 2>/dev/null | head -1
}

get_container_image_size() {
    local container_name="$1"
    local image
    image=$(get_container_image "$container_name")
    get_image_size "$image"
}

# -----------------------------------------------------------------------------
# 日志操作
# -----------------------------------------------------------------------------
get_container_logs() {
    local container_name="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$container_name" 2>&1
}

get_container_error_logs() {
    local container_name="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" --stderr "$container_name" 2>&1
}

grep_container_logs() {
    local container_name="$1"
    local pattern="$2"
    local lines="${3:-500}"
    docker logs --tail "$lines" "$container_name" 2>&1 | grep "$pattern"
}

container_has_errors() {
    local container_name="$1"
    local lines="${2:-100}"
    local error_patterns=("error" "Error" "ERROR" "fatal" "FATAL" "exception" "Exception")
    for pattern in "${error_patterns[@]}"; do
        if grep_container_logs "$container_name" "$pattern" "$lines" | grep -qv "error_count\|error_log\|ErrorLog"; then
            return 0
        fi
    done
    return 1
}

# -----------------------------------------------------------------------------
# 卷操作
# -----------------------------------------------------------------------------
get_container_volumes() {
    local container_name="$1"
    docker inspect -f '{{range .Mounts}}{{.Name}}:{{.Destination}}:{{.Mode}} {{end}}' "$container_name" 2>/dev/null
}

volume_exists() {
    local volume_name="$1"
    docker volume ls --format '{{.Name}}' | grep -q "^${volume_name}$"
}

# -----------------------------------------------------------------------------
# 调试辅助
# -----------------------------------------------------------------------------
dump_container_info() {
    local container_name="$1"
    echo "=== Container: $container_name ==="
    echo "State: $(get_container_state "$container_name")"
    echo "Image: $(get_container_image "$container_name")"
    echo "IP: $(get_container_ip_address "$container_name")"
    echo "Ports: $(get_container_ports "$container_name")"
    echo "Uptime: $(get_container_uptime "$container_name")s"
    echo "Restart Count: $(get_container_restart_count "$container_name")"
    echo "Memory: $(get_container_memory_usage "$container_name")"
}

check_docker_daemon() {
    if ! docker info &>/dev/null; then
        echo "ERROR: Cannot connect to Docker daemon"
        echo "Please ensure Docker is running and you have permissions"
        return 1
    fi
    return 0
}

export -f docker_available get_docker_version get_docker_compose_version
export -f docker_network_exists docker_network_ensure
export -f list_containers list_running_containers list_stopped_containers
export -f get_container_state is_container_running get_container_exit_code
export -f get_container_restart_count get_container_created get_container_started get_container_uptime
export -f get_container_image get_container_log_size get_container_ports
export -f get_container_ip_address get_container_networks get_container_hostname
export -f can_container_resolve can_container_connect
export -f get_container_cpu_percent get_container_memory_usage get_container_memory_percent
export -f get_container_network_io get_container_block_io
export -f compose_file_exists get_compose_service_state get_compose_services_state
export -f is_compose_service_running wait_compose_service get_compose_service_health
export -f image_exists get_image_size get_container_image_size
export -f get_container_logs get_container_error_logs grep_container_logs container_has_errors
export -f get_container_volumes volume_exists
export -f dump_container_info check_docker_daemon
