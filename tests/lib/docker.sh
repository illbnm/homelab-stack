#!/usr/bin/env bash
# =============================================================================
# HomeLab Integration Tests — Docker Utility Functions
#
# Helper functions for Docker operations used across test scripts.
# =============================================================================

# ---------------------------------------------------------------------------
# wait_for_healthy <container> [timeout=120]
# Waits for a container to report healthy status.
# Returns 0 on healthy, 1 on timeout.
# ---------------------------------------------------------------------------
wait_for_healthy() {
  local container="$1"
  local timeout="${2:-120}"
  local health=""

  for ((i = 0; i < timeout; i++)); do
    health=$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null) || true
    if [[ "${health}" == "healthy" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ---------------------------------------------------------------------------
# wait_for_container <container> [timeout=60]
# Waits for a container to exist and be running.
# ---------------------------------------------------------------------------
wait_for_container() {
  local container="$1"
  local timeout="${2:-60}"

  for ((i = 0; i < timeout; i++)); do
    local running
    running=$(docker inspect --format='{{.State.Running}}' "${container}" 2>/dev/null) || true
    if [[ "${running}" == "true" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ---------------------------------------------------------------------------
# wait_for_http <url> [timeout=60]
# Waits for an HTTP endpoint to return 200.
# ---------------------------------------------------------------------------
wait_for_http() {
  local url="$1"
  local timeout="${2:-60}"

  for ((i = 0; i < timeout; i++)); do
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null) || true
    if [[ "${code}" == "200" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ---------------------------------------------------------------------------
# get_container_ip <container> [network]
# Returns the IP address of a container, optionally on a specific network.
# ---------------------------------------------------------------------------
get_container_ip() {
  local container="$1"
  local network="${2:-}"

  if [[ -n "${network}" ]]; then
    docker inspect --format="{{(index .NetworkSettings.Networks \"${network}\").IPAddress}}" "${container}" 2>/dev/null
  else
    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "${container}" 2>/dev/null | grep -v '^$' | head -1
  fi
}

# ---------------------------------------------------------------------------
# get_container_port <container> <internal_port>
# Returns the host-mapped port for a container's internal port.
# ---------------------------------------------------------------------------
get_container_port() {
  local container="$1"
  local port="$2"

  docker port "${container}" "${port}" 2>/dev/null | sed 's/.*://'
}

# ---------------------------------------------------------------------------
# get_compose_services <compose_file>
# Lists all service names from a compose file.
# ---------------------------------------------------------------------------
get_compose_services() {
  local file="$1"

  docker compose -f "${file}" config --services 2>/dev/null
}

# ---------------------------------------------------------------------------
# is_stack_running <stack_dir>
# Returns 0 if at least one container from the stack is running.
# ---------------------------------------------------------------------------
is_stack_running() {
  local stack_dir="$1"
  local compose_file="${stack_dir}/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    return 1
  fi

  local running
  running=$(docker compose -f "${compose_file}" ps -q 2>/dev/null | wc -l | tr -d ' ')

  [[ "${running}" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# get_container_logs <container> [lines=50]
# Returns the last N lines of container logs.
# ---------------------------------------------------------------------------
get_container_logs() {
  local container="$1"
  local lines="${2:-50}"

  docker logs --tail "${lines}" "${container}" 2>&1
}

# ---------------------------------------------------------------------------
# compose_config_valid <compose_file>
# Validates docker compose syntax. Returns 0 if valid.
# ---------------------------------------------------------------------------
compose_config_valid() {
  local file="$1"

  docker compose -f "${file}" config --quiet 2>&1
}

# ---------------------------------------------------------------------------
# get_image_tag <compose_file> <service>
# Returns the image tag for a service in a compose file.
# ---------------------------------------------------------------------------
get_image_tag() {
  local file="$1"
  local service="$2"

  docker compose -f "${file}" config 2>/dev/null | \
    grep -A1 "\"${service}\":" | grep "image:" | awk '{print $2}' || \
    docker compose -f "${file}" config --format json 2>/dev/null | \
    jq -r ".services.\"${service}\".image // empty"
}
