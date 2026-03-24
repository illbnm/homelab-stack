#!/usr/bin/env bash
# =============================================================================
# Docker Helper Functions
# =============================================================================

docker_is_running() {
  docker info >/dev/null 2>&1
}

container_exists() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

container_is_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

container_health() {
  docker inspect --format '{{.State.Health.Status}}' "$1" 2>/dev/null || echo "no-healthcheck"
}

wait_for_container() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    if container_is_running "$name"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

list_running_containers() {
  docker ps --format '{{.Names}}' 2>/dev/null | sort
}
