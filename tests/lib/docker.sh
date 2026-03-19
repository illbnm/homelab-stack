#!/usr/bin/env bash
# =============================================================================
# tests/lib/docker.sh — Docker 工具函数
# =============================================================================

# Get container health status
docker_health_status() {
  local name="$1"
  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
    "$name" 2>/dev/null || echo "unknown"
}

# Get container status (running, exited, etc.)
docker_status() {
  local name="$1"
  docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "missing"
}

# Wait for container to be running (not health)
docker_wait_running() {
  local name="$1" timeout="${2:-60}"
  local waited=0
  while [[ $waited -lt $timeout ]]; do
    local status
    status=$(docker_status "$name")
    [[ "$status" == "running" ]] && return 0
    sleep 2
    waited=$((waited + 2))
  done
  return 1
}

# Wait for HTTP endpoint
docker_wait_http() {
  local name="$1" path="${2:-/}" timeout="${3:-60}" port="${4:-}"
  local waited=0
  local url="http://localhost"

  # Determine port if not provided
  if [[ -z "$port" ]]; then
    port=$(docker port "$name" 2>/dev/null | grep -E ':(80|443|[0-9]+)->' | head -1 | sed 's/.*->//' | cut -d/ -f1 || echo "")
    [[ -z "$port" ]] && port=80
  fi

  # Get container IP
  local ip
  ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null || echo "")

  [[ -n "$ip" ]] && url="http://$ip:$port$path" || url="http://localhost:$port$path"

  while [[ $waited -lt $timeout ]]; do
    if curl -sf --connect-timeout 2 --max-time 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  return 1
}

# Get container logs
docker_get_logs() {
  local name="$1" lines="${2:-20}"
  docker logs --tail "$lines" "$name" 2>&1
}

# Get all container names for a compose stack
docker_stack_containers() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps --format '{{.Name}}' 2>/dev/null
}

# Check if port is open locally
port_open() {
  local host="${1:-localhost}" port="$2" timeout="${3:-3}"
  nc -z -w"$timeout" "$host" "$port" 2>/dev/null
}

# Get HTTP status code
http_status() {
  local url="$1" timeout="${2:-10}"
  curl -sf --connect-timeout 5 --max-time "$timeout" \
    -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000"
}
