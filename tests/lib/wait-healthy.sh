#!/usr/bin/env bash
# wait-healthy.sh — Wait for containers to reach healthy state with timeout

# Usage: wait_for_healthy <container_name> [timeout_seconds]
wait_for_healthy() {
  local container="$1"
  local timeout="${2:-60}"
  local elapsed=0

  echo "Waiting for '${container}' to become healthy (timeout: ${timeout}s)..."

  while [[ $elapsed -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")

    case "$health" in
      healthy)
        echo "'${container}' is healthy after ${elapsed}s"
        return 0
        ;;
      unhealthy)
        echo "'${container}' is unhealthy after ${elapsed}s"
        return 1
        ;;
      not_found)
        echo "Container '${container}' not found"
        return 1
        ;;
      *)
        sleep 2
        elapsed=$((elapsed + 2))
        ;;
    esac
  done

  echo "Timeout waiting for '${container}' to become healthy after ${timeout}s"
  return 1
}

# Wait for multiple containers
wait_for_all_healthy() {
  local timeout="${1:-60}"
  shift
  local containers=("$@")
  local all_ok=0

  for container in "${containers[@]}"; do
    if ! wait_for_healthy "$container" "$timeout"; then
      all_ok=1
    fi
  done

  return $all_ok
}
