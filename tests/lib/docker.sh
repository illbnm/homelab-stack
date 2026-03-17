#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Functions
# =============================================================================
# Helper functions for interacting with Docker in tests.
#
# Usage:
#   source tests/lib/docker.sh
# =============================================================================

# Guard against double-sourcing
[[ -n "${__DOCKER_SH_LOADED:-}" ]] && return 0
readonly __DOCKER_SH_LOADED=1

# ---------------------------------------------------------------------------
# Container inspection
# ---------------------------------------------------------------------------

# docker_container_exists <container_name>
# Returns 0 if the container exists (running or not), 1 otherwise.
docker_container_exists() {
  local name="$1"
  docker inspect "${name}" &>/dev/null
}

# docker_container_running <container_name>
# Returns 0 if the container is running, 1 otherwise.
docker_container_running() {
  local name="$1"
  local running
  running=$(docker inspect --format='{{.State.Running}}' "${name}" 2>/dev/null || echo "false")
  [[ "${running}" == "true" ]]
}

# docker_container_health <container_name>
# Echoes the health status string (healthy, unhealthy, starting, none, not found).
docker_container_health() {
  local name="$1"
  docker inspect --format='{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "not found"
}

# docker_container_image <container_name>
# Returns the image name:tag of the container.
docker_container_image() {
  local name="$1"
  docker inspect --format='{{.Config.Image}}' "${name}" 2>/dev/null || echo ""
}

# docker_container_networks <container_name>
# Returns space-separated list of networks the container is on.
docker_container_networks() {
  local name="$1"
  docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "${name}" 2>/dev/null || echo ""
}

# docker_container_ports <container_name>
# Returns host-mapped ports, empty if no ports mapped.
docker_container_ports() {
  local name="$1"
  docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}} {{end}}{{end}}' "${name}" 2>/dev/null || echo ""
}

# docker_container_env <container_name> <env_var_name>
# Returns the value of an environment variable inside a container.
docker_container_env() {
  local name="$1"
  local var="$2"
  docker exec "${name}" printenv "${var}" 2>/dev/null || echo ""
}

# docker_container_uptime_seconds <container_name>
# Returns how many seconds the container has been running.
docker_container_uptime_seconds() {
  local name="$1"
  local started_at
  started_at=$(docker inspect --format='{{.State.StartedAt}}' "${name}" 2>/dev/null || echo "")

  if [[ -z "${started_at}" ]]; then
    echo "0"
    return
  fi

  local start_epoch now_epoch
  start_epoch=$(date -d "${started_at}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%%.*}" +%s 2>/dev/null || echo "0")
  now_epoch=$(date +%s)
  echo $(( now_epoch - start_epoch ))
}

# ---------------------------------------------------------------------------
# Stack operations
# ---------------------------------------------------------------------------

# docker_compose_up <compose_file> [extra_args...]
# Starts a compose stack in detached mode.
docker_compose_up() {
  local file="$1"
  shift
  docker compose -f "${file}" up -d "$@" 2>&1
}

# docker_compose_down <compose_file> [extra_args...]
# Stops and removes a compose stack.
docker_compose_down() {
  local file="$1"
  shift
  docker compose -f "${file}" down "$@" 2>&1
}

# docker_compose_ps <compose_file>
# Lists services and their status.
docker_compose_ps() {
  local file="$1"
  docker compose -f "${file}" ps 2>&1
}

# docker_compose_services <compose_file>
# Returns a list of service names defined in the compose file.
docker_compose_services() {
  local file="$1"
  docker compose -f "${file}" config --services 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Wait helpers
# ---------------------------------------------------------------------------

# wait_for_healthy <container_name> [timeout=120]
# Blocks until the container becomes healthy or times out.
# Returns 0 on healthy, 1 on timeout.
wait_for_healthy() {
  local name="$1"
  local timeout="${2:-120}"
  local waited=0

  while [[ "${waited}" -lt "${timeout}" ]]; do
    local status
    status=$(docker_container_health "${name}")

    if [[ "${status}" == "healthy" ]]; then
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  return 1
}

# wait_for_http <url> [timeout=60]
# Blocks until the URL returns HTTP 200 or times out.
# Returns 0 on success, 1 on timeout.
wait_for_http() {
  local url="$1"
  local timeout="${2:-60}"
  local waited=0

  while [[ "${waited}" -lt "${timeout}" ]]; do
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' \
      --max-time 5 --connect-timeout 5 \
      -k -L "${url}" 2>/dev/null || echo "000")

    if [[ "${code}" == "200" ]]; then
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  return 1
}

# wait_for_log <container_name> <pattern> [timeout=60]
# Blocks until a log line matching <pattern> appears.
wait_for_log() {
  local name="$1"
  local pattern="$2"
  local timeout="${3:-60}"
  local waited=0

  while [[ "${waited}" -lt "${timeout}" ]]; do
    if docker logs "${name}" 2>&1 | grep -q "${pattern}"; then
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  return 1
}

# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

# docker_network_exists <network_name>
docker_network_exists() {
  local name="$1"
  docker network inspect "${name}" &>/dev/null
}

# docker_network_create_if_missing <network_name>
docker_network_create_if_missing() {
  local name="$1"
  if ! docker_network_exists "${name}"; then
    docker network create "${name}" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Exec helpers
# ---------------------------------------------------------------------------

# docker_exec <container_name> <command...>
# Runs a command inside a container. Returns the exit code.
docker_exec() {
  local name="$1"
  shift
  docker exec "${name}" "$@" 2>/dev/null
}

# docker_exec_output <container_name> <command...>
# Runs a command inside a container and captures stdout.
docker_exec_output() {
  local name="$1"
  shift
  docker exec "${name}" "$@" 2>/dev/null || echo ""
}
