#!/usr/bin/env bash
# Docker utility functions for tests
set -euo pipefail

docker_running() {
  docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -q "true"
}

docker_healthy() {
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = "healthy" ]
}

docker_exec_check() {
  local container="$1"
  shift
  docker exec "$container" "$@" >/dev/null 2>&1
}

wait_for_healthy() {
  local container="$1" timeout="${2:-60}"
  local elapsed=0
  while [ $elapsed -lt "$timeout" ]; do
    if docker_healthy "$container"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}
