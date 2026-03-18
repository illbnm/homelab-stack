#!/usr/bin/env bash
# =============================================================================
# docker.sh — Docker utility functions for integration tests
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Container helpers
# ---------------------------------------------------------------------------

# Wait for a container to become healthy (or running if no healthcheck)
# Usage: wait_container_healthy <container_name> [timeout_seconds]
wait_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local start=$SECONDS

  echo -n "  ⏳ Waiting for ${name}..."

  while (( SECONDS - start < timeout )); do
    local state
    state=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null) || {
      sleep 2
      continue
    }

    if [[ "$state" != "running" ]]; then
      sleep 2
      continue
    fi

    local health
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null)

    case "$health" in
      healthy|no-healthcheck)
        echo -e " ready ($(( SECONDS - start ))s)"
        return 0
        ;;
    esac

    sleep 2
  done

  echo -e " timeout!"
  return 1
}

# Wait for all containers in a compose project to be running
# Usage: wait_compose_up <compose_file> [timeout_seconds]
wait_compose_up() {
  local compose_file="$1"
  local timeout="${2:-120}"
  local start=$SECONDS

  echo "  ⏳ Waiting for all services in ${compose_file}..."

  while (( SECONDS - start < timeout )); do
    local total running
    total=$(docker compose -f "$compose_file" ps --format json 2>/dev/null | jq -s 'length')
    running=$(docker compose -f "$compose_file" ps --format json 2>/dev/null | jq -s '[.[] | select(.State == "running")] | length')

    if [[ "$total" -gt 0 ]] && [[ "$total" == "$running" ]]; then
      echo "  ✓ All ${total} services running ($(( SECONDS - start ))s)"
      return 0
    fi

    sleep 3
  done

  echo "  ✗ Timeout waiting for services"
  return 1
}

# Get container IP in a specific Docker network
# Usage: get_container_ip <container_name> [network_name]
get_container_ip() {
  local container="$1"
  local network="${2:-bridge}"

  docker inspect --format="{{.NetworkSettings.Networks.${network}.IPAddress}}" "$container" 2>/dev/null
}

# Get container port mapping
# Usage: get_container_port <container_name> <container_port>
get_container_port() {
  local container="$1"
  local port="$2"

  docker port "$container" "$port" 2>/dev/null | head -1 | cut -d: -f2
}

# Execute a command inside a container and return output
# Usage: container_exec <container_name> <command...>
container_exec() {
  local container="$1"
  shift
  docker exec "$container" "$@" 2>/dev/null
}

# Get the restart count of a container
# Usage: get_restart_count <container_name>
get_restart_count() {
  local name="$1"
  docker inspect --format='{{.RestartCount}}' "$name" 2>/dev/null || echo "-1"
}

# Check if a container has restarted too many times (crash loop detection)
# Usage: assert_no_crash_loop <container_name> [max_restarts]
assert_no_crash_loop() {
  local name="$1"
  local max="${2:-3}"
  local msg="Container '${name}' has not crash-looped (max ${max} restarts)"

  local count
  count=$(get_restart_count "$name")

  if [[ "$count" -le "$max" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Restart count: ${count}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Compose helpers
# ---------------------------------------------------------------------------

# Start a stack with compose
# Usage: compose_up <compose_file> [extra_args]
compose_up() {
  local compose_file="$1"
  shift
  docker compose -f "$compose_file" up -d "$@" 2>&1
}

# Stop a stack
# Usage: compose_down <compose_file>
compose_down() {
  local compose_file="$1"
  docker compose -f "$compose_file" down -v --remove-orphans 2>&1
}

# Get list of service names from compose file
# Usage: get_compose_services <compose_file>
get_compose_services() {
  local compose_file="$1"
  docker compose -f "$compose_file" config --services 2>/dev/null
}

# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------

# Check if a Docker image is pullable (useful for CI pre-checks)
# Usage: assert_image_pullable <image_name>
assert_image_pullable() {
  local image="$1"
  local msg="Image '${image}' is pullable"

  if docker manifest inspect "$image" &>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Image not found in registry"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Cleanup helpers
# ---------------------------------------------------------------------------

# Remove test containers
cleanup_test_containers() {
  local prefix="${1:-homelab-test}"
  docker ps -a --filter "name=${prefix}" --format '{{.ID}}' | xargs -r docker rm -f 2>/dev/null || true
}

# Remove test networks
cleanup_test_networks() {
  local prefix="${1:-homelab-test}"
  docker network ls --filter "name=${prefix}" --format '{{.ID}}' | xargs -r docker network rm 2>/dev/null || true
}

# Remove test volumes
cleanup_test_volumes() {
  local prefix="${1:-homelab-test}"
  docker volume ls --filter "name=${prefix}" --format '{{.Name}}' | xargs -r docker volume rm 2>/dev/null || true
}
