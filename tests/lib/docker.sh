#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Docker.sh — Docker 操作工具函数库
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 通用 Docker 操作
# ═══════════════════════════════════════════════════════════════════════════

# docker_compose_up <compose_file> [detach=true]
docker_compose_up() {
  local compose_file="$1"
  local detach="${2:-true}"

  if [[ ! -f "$compose_file" ]]; then
    echo "ERROR: Compose file not found: $compose_file" >&2
    return 1
  fi

  echo "Starting services from $compose_file..."
  if [[ "$detach" == "true" ]]; then
    docker compose -f "$compose_file" up -d
  else
    docker compose -f "$compose_file" up
  fi
}

# docker_compose_down <compose_file>
docker_compose_down() {
  local compose_file="$1"

  echo "Stopping services from $compose_file..."
  docker compose -f "$compose_file" down -v 2>/dev/null || true
}

# docker_compose_config <compose_file>
docker_compose_config() {
  local compose_file="$1"
  docker compose -f "$compose_file" config
}

# docker_compose_logs <compose_file> [service]
docker_compose_logs() {
  local compose_file="$1"
  local service="${2:-}"
  docker compose -f "$compose_file" logs "$service"
}

# docker_compose_ps <compose_file>
docker_compose_ps() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps
}

# ═══════════════════════════════════════════════════════════════════════════
# 健康检查与等待
# ═══════════════════════════════════════════════════════════════════════════

# wait_for_container <container> [timeout=60]
wait_for_container() {
  local container="$1"
  local timeout="${2:-60}"
  local start=$(date +%s)

  echo -n "Waiting for container '$container' to be running..."
  while true; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      echo " ✅"
      return 0
    fi

    local elapsed=$(($(date +%s) - start))
    if [[ $elapsed -ge $timeout ]]; then
      echo " ❌ (timeout after ${timeout}s)"
      return 1
    fi
    sleep 2
  done
}

# wait_for_container_healthy <container> [timeout=90]
wait_for_container_healthy() {
  local container="$1"
  local timeout="${2:-90}"
  local start=$(date +%s)

  echo -n "Waiting for container '$container' to be healthy..."
  while true; do
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    if [[ "$status" == "healthy" ]]; then
      echo " ✅"
      return 0
    elif [[ "$status" == "unhealthy" ]]; then
      echo " ❌ (unhealthy)"
      return 1
    fi

    local elapsed=$(($(date +%s) - start))
    if [[ $elapsed -ge $timeout ]]; then
      echo " ❌ (timeout after ${timeout}s, status: $status)"
      return 1
    fi
    sleep 3
  done
}

# wait_for_http <url> [timeout=30] [expected_code=200]
wait_for_http() {
  local url="$1"
  local timeout="${2:-30}"
  local expected_code="${3:-200}"
  local start=$(date +%s)

  echo -n "Waiting for HTTP $expected_code from $url..."
  while true; do
    local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "$expected_code" ]]; then
      echo " ✅"
      return 0
    fi

    local elapsed=$(($(date +%s) - start))
    if [[ $elapsed -ge $timeout ]]; then
      echo " ❌ (got $code after ${timeout}s)"
      return 1
    fi
    sleep 2
  done
}

# wait_for_port <host> <port> [timeout=30]
wait_for_port() {
  local host="$1"
  local port="$2"
  local timeout="${3:-30}"
  local start=$(date +%s)

  echo -n "Waiting for $host:$port to be open..."
  while true; do
    if nc -z "$host" "$port" 2>/dev/null; then
      echo " ✅"
      return 0
    fi

    local elapsed=$(($(date +%s) - start))
    if [[ $elapsed -ge $timeout ]]; then
      echo " ❌ (timeout after ${timeout}s)"
      return 1
    fi
    sleep 1
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# 容器信息查询
# ═══════════════════════════════════════════════════════════════════════════

# get_container_id <container_name>
get_container_id() {
  local name="$1"
  docker ps --filter "name=^${name}$" --format '{{.ID}}' | head -1
}

# get_container_ip <container_name>
get_container_ip() {
  local name="$1"
  docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null | head -1
}

# get_container_port <container> <port> [protocol=tcp]
get_container_port() {
  local container="$1"
  local port="$2"
  local protocol="${3:-tcp}"

  docker port "$container" "$port/$protocol" 2>/dev/null | cut -d: -f2 | head -1
}

# container_is_running <container>
container_is_running() {
  local container="$1"
  docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

# container_is_healthy <container>
container_is_healthy() {
  local container="$1"
  local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health")
  [[ "$status" == "healthy" ]]
}

# ═══════════════════════════════════════════════════════════════════════════
# Docker Compose 文件解析
# ═══════════════════════════════════════════════════════════════════════════

# get_services_from_compose <compose_file>
get_services_from_compose() {
  local compose_file="$1"
  docker compose -f "$compose_file" config --services 2>/dev/null || true
}

# get_service_image <compose_file> <service>
get_service_image() {
  local compose_file="$1"
  local service="$2"
  docker compose -f "$compose_file" config --services "$service" 2>/dev/null | grep "^image:" | awk '{print $2}' || echo ""
}

# get_service_healthcheck <compose_file> <service>
get_service_healthcheck() {
  local compose_file="$1"
  local service="$2"

  # 提取 healthcheck 配置
  docker compose -f "$compose_file" config 2>/dev/null | \
    awk "/^  $service:/,/^[^ ]/" | \
    grep -A5 "healthcheck:" || echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# 网络与卷管理
# ═══════════════════════════════════════════════════════════════════════════

# docker_network_exists <network>
docker_network_exists() {
  local network="$1"
  docker network ls --format '{{.Name}}' | grep -q "^${network}$"
}

# docker_volume_exists <volume>
docker_volume_exists() {
  local volume="$1"
  docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"
}

# create_docker_network <name> [driver=bridge]
create_docker_network() {
  local name="$1"
  local driver="${2:-bridge}"

  if docker_network_exists "$name"; then
    echo "Network '$name' already exists"
    return 0
  fi

  docker network create --driver "$driver" "$name"
}

# ═══════════════════════════════════════════════════════════════════════════
# 镜像管理
# ═══════════════════════════════════════════════════════════════════════════

# pull_image_if_missing <image>
pull_image_if_missing() {
  local image="$1"

  if docker image inspect "$image" &>/dev/null; then
    echo "Image '$image' already exists"
    return 0
  fi

  echo "Pulling image '$image'..."
  docker pull "$image"
}

# image_has_tag_latest <image>
image_has_tag_latest() {
  local image="$1"
  [[ "$image" == *":latest" ]]
}

# ═════════════════════════════════════════════════════════ compose_files_with_latest_tags <dir>
compose_files_with_latest_tags() {
  local dir="$1"
  grep -r 'image:.*:latest' "$dir" 2>/dev/null | cut -d: -f1 | sort -u
}

# ═══════════════════════════════════════════════════════════════════════════
# 日志与调试
# ═══════════════════════════════════════════════════════════════════════════

# get_container_logs <container> [lines=100]
get_container_logs() {
  local container="$1"
  local lines="${2:-100}"
  docker logs --tail "$lines" "$container" 2>&1
}

# get_container_health_details <container>
get_container_health_details() {
  local container="$1"
  docker inspect --format='{{json .State.Health}}' "$container" | jq -r '.Log | map("\(.Start) \(.End) \(.ExitCode) \(.Output)") | .[]' 2>/dev/null || echo "No health logs"
}

# ═══════════════════════════════════════════════════════════════════════════
# 导出
# ═══════════════════════════════════════════════════════════════════════════

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This library is meant to be sourced, not executed directly."
  exit 1
fi