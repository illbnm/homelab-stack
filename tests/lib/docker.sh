#!/usr/bin/env bash
# Docker utility functions for homelab-stack tests
set -euo pipefail

get_container_status() {
  docker inspect --format '{{.State.Status}}' "$1" 2>/dev/null || echo "not-found"
}

get_container_health() {
  docker inspect --format '{{.State.Health.Status}}' "$1" 2>/dev/null || echo "none"
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^${1}$"
}

container_is_running() {
  docker ps --format '{{.Names}}' | grep -q "^${1}$"
}

list_stack_containers() {
  local stack="$1"
  docker ps --filter "label=com.docker.compose.project=$stack" --format '{{.Names}}'
}

get_container_logs() {
  docker logs --tail 30 "$1" 2>&1
}

wait_for_healthy() {
  local container="$1" timeout="${2:-60}"
  local waited=0 interval=3
  while [[ $waited -lt $timeout ]]; do
    local status
    status=$(get_container_health "$container")
    [[ "$status" == "healthy" ]] && return 0
    sleep $interval
    waited=$((waited + interval))
  done
  return 1
}