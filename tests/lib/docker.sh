#!/usr/bin/env bash
# =============================================================================
# docker.sh — Docker utility functions
# =============================================================================
set -uo pipefail

check_docker() {
  if ! docker info &>/dev/null; then
    echo "ERROR: Docker daemon is not running" >&2
    return 1
  fi
  return 0
}

wait_for_healthy() {
  local container="$1" timeout="${2:-120}"
  local elapsed=0
  while (( elapsed < timeout )); do
    local status
    status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "missing")
    [[ "$status" == "missing" ]] && { echo "Container $container not found" >&2; return 1; }
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    [[ "$health" == "healthy" || "$health" == "none" ]] && return 0
    sleep 3; ((elapsed+=3))
  done
  echo "Container $container not healthy within ${timeout}s" >&2
  return 1
}

check_network() {
  local name="$1"
  docker network inspect "$name" &>/dev/null
}

get_compose_services() {
  local compose_file="$1"
  docker compose -f "$compose_file" config --services 2>/dev/null
}

docker_compose_validate() {
  local compose_file="$1"
  docker compose -f "$compose_file" config --quiet 2>&1
}
