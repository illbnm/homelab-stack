#!/usr/bin/env bash
# docker.sh — Docker utility helpers for homelab-stack tests

# Wait for a container to reach 'running' state
docker_wait_running() {
  local container="$1"
  local timeout="${2:-30}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local status
    status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
    if [[ "$status" == "running" ]]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Wait for a container to reach 'healthy' state
docker_wait_healthy() {
  local container="$1"
  local timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
    if [[ "$health" == "healthy" ]]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Get a container's IP address on a given network
docker_container_ip() {
  local container="$1"
  local network="${2:-bridge}"
  docker inspect --format "{{(index .NetworkSettings.Networks \"${network}\").IPAddress}}" "$container" 2>/dev/null || echo ""
}

# Check if a container exists
docker_container_exists() {
  local container="$1"
  docker inspect "$container" &>/dev/null
}

# Get a container's environment variable value
docker_container_env() {
  local container="$1"
  local var_name="$2"
  docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$container" 2>/dev/null \
    | grep "^${var_name}=" | cut -d= -f2- || echo ""
}

# Check if docker compose project is running
docker_compose_running() {
  local project="$1"
  docker compose --project-name "$project" ps --quiet 2>/dev/null | grep -q .
}

# Get the list of containers for a compose project
docker_compose_containers() {
  local project="$1"
  docker compose --project-name "$project" ps --format json 2>/dev/null \
    | jq -r '.[].Name' 2>/dev/null || echo ""
}
