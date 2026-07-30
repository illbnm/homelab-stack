#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Docker Tool Functions — Container/Compose Helpers
# ════════════════════════════════════════════════════════════════

# Check if a container is running
container_running() {
  local name="$1"
  docker ps --filter "name=^${name}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Check if a container is healthy
container_healthy() {
  local name="$1"
  local status
  status=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "")
  [[ "$status" == "healthy" ]]
}

# Check if a container exists (running or stopped)
container_exists() {
  local name="$1"
  docker ps -a --filter "name=^${name}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Get container IP on a specific network
container_ip() {
  local name="$1" network="${2:-homelab}"
  docker inspect --format "{{range .NetworkSettings.Networks}}{{if eq .NetworkName \"${network}\"}}{{.IPAddress}}{{end}}{{end}}" "$name" 2>/dev/null
}

# Get container status
container_status() {
  local name="$1"
  docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found"
}

# Get exposed port mapping
container_port() {
  local name="$1" port="$2"
  docker port "$name" "$port" 2>/dev/null | head -1
}

# Get compose service logs (last N lines)
compose_logs() {
  local service="$1" lines="${2:-50}"
  docker compose logs --tail="$lines" "$service" 2>/dev/null
}

# Wait for container to be healthy (with timeout)
wait_for_healthy() {
  local name="$1" timeout="${2:-120}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    if container_healthy "$name"; then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  return 1
}

# Wait for HTTP endpoint to respond
wait_for_http() {
  local url="$1" timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    if [[ "$code" != "000" && "$code" != "" ]]; then
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  return 1
}

# Get compose project services
compose_services() {
  local compose_file="${1:-docker-compose.yml}"
  docker compose -f "$compose_file" config --services 2>/dev/null
}

# Check if a docker network exists
network_exists() {
  local name="${1:-homelab}"
  docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"
}

# Execute command inside a container
exec_in_container() {
  local name="$1"
  shift
  docker exec "$name" "$@" 2>/dev/null
}

# Get container image
container_image() {
  local name="$1"
  docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo ""
}

# Count running containers matching a pattern
count_containers() {
  local pattern="${1:-.*}"
  docker ps --filter "name=${pattern}" --format '{{.Names}}' 2>/dev/null | wc -l
}

# Check if two containers can communicate
containers_can_ping() {
  local from="$1" to="$2"
  local to_ip
  to_ip=$(container_ip "$to")
  if [[ -z "$to_ip" ]]; then
    return 1
  fi
  exec_in_container "$from" ping -c 1 -W 2 "$to_ip" &>/dev/null
}

# Get volume mount path
volume_mount_path() {
  local container="$1" dest="$2"
  docker inspect --format "{{range .Mounts}}{{if eq .Destination \"${dest}\"}}{{.Source}}{{end}}{{end}}" "$container" 2>/dev/null
}