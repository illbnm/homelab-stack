#!/usr/bin/env bash
# =============================================================================
# docker.sh — Docker utility functions for integration tests
# =============================================================================

# Check if a Docker network exists
# Usage: docker_network_exists "network_name"
docker_network_exists() {
  docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${1}$"
}

# Check if a Docker volume exists
# Usage: docker_volume_exists "volume_name"
docker_volume_exists() {
  docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${1}$"
}

# Get a container's IP address on a given network
# Usage: docker_container_ip "container_name" "network_name"
docker_container_ip() {
  local name="$1" network="$2"
  docker inspect -f "{{.NetworkSettings.Networks.${network}.IPAddress}}" "$name" 2>/dev/null
}

# Run a command inside a running container
# Usage: docker_run_in "container_name" "command" [args...]
docker_run_in() {
  local name="$1"
  shift
  docker exec "$name" "$@" 2>/dev/null
}

# Get the restart count for a container
# Usage: docker_restart_count "container_name"
docker_restart_count() {
  docker inspect --format '{{.RestartCount}}' "$1" 2>/dev/null || echo "-1"
}

# Check if a container has a specific label
# Usage: docker_has_label "container_name" "label_key"
docker_has_label() {
  local name="$1" label="$2"
  local val
  val=$(docker inspect --format "{{index .Config.Labels \"$label\"}}" "$name" 2>/dev/null || echo "")
  [[ -n "$val" ]]
}

# Get the image name of a running container
# Usage: docker_image "container_name"
docker_image() {
  docker inspect --format '{{.Config.Image}}' "$1" 2>/dev/null
}

# Wait for a container to become healthy (with timeout)
# Usage: docker_wait_healthy "container_name" [timeout_seconds]
docker_wait_healthy() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0
  while (( elapsed < timeout )); do
    local status
    status=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
    if [[ "$status" == "healthy" || "$status" == "none" ]]; then
      return 0
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
  done
  return 1
}

# List all running containers matching a prefix
# Usage: docker_containers_with_prefix "prefix"
docker_containers_with_prefix() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep "^${1}" || true
}

# Get the compose project for a container
# Usage: docker_compose_project "container_name"
docker_compose_project() {
  docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$1" 2>/dev/null
}

# Check if a stack's compose file exists
# Usage: stack_compose_exists "stack_name"
stack_compose_exists() {
  local stack="$1"
  [[ -f "${BASE_DIR}/stacks/${stack}/docker-compose.yml" ]]
}

# Check if a stack is deployed (at least one container running)
# Usage: stack_is_running "stack_name"
stack_is_running() {
  local stack="$1"
  docker ps --format '{{.Labels}}' 2>/dev/null | grep -q "com.docker.compose.project.working_dir=.*${stack}" 2>/dev/null
}
