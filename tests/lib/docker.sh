#!/usr/bin/env bash

# Docker Utility Library for HomeLab Stack Integration Tests
#
# Provides functions to interact with Docker and Docker Compose.
#
# Dependencies:
#   docker, docker compose (v2)

# --- Docker Helper Functions ---

# get_container_ip <container_name>
# Returns the IP address of a running container.
get_container_ip() {
  local container_name="$1"
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}" 2>/dev/null
}

# wait_for_container_status <container_name> <status> [timeout=60] [interval=2]
# Waits for a container to reach a specific status (e.g., "running", "exited").
wait_for_container_status() {
  local container_name="$1"
  local expected_status="$2"
  local timeout="${3:-60}"
  local interval="${4:-2}"
  local elapsed=0

  echo "Waiting for container '${container_name}' to be '${expected_status}' (timeout: ${timeout}s)..." >&2

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    local current_status=$(docker inspect -f '{{.State.Status}}' "${container_name}" 2>/dev/null || echo "not_found")
    if [[ "${current_status}" == "${expected_status}" ]]; then
      echo "Container '${container_name}' is '${expected_status}'." >&2
      return 0
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  echo "Error: Container '${container_name}' did not reach '${expected_status}' status within ${timeout}s. Current status: ${current_status}" >&2
  return 1
}

# wait_for_container_health <container_name> [timeout=60] [interval=2]
# Waits for a container to become healthy according to its Docker healthcheck.
wait_for_container_health() {
  local container_name="$1"
  local timeout="${2:-60}"
  local interval="${4:-2}"
  local elapsed=0

  echo "Waiting for container '${container_name}' to be healthy (timeout: ${timeout}s)..." >&2

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    local health_status=$(docker inspect -f '{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "not_found")
    if [[ "${health_status}" == "healthy" ]]; then
      echo "Container '${container_name}' is healthy." >&2
      return 0
    elif [[ "${health_status}" == "unhealthy" ]]; then
      echo "Error: Container '${container_name}' became unhealthy." >&2
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  echo "Error: Container '${container_name}' did not become healthy within ${timeout}s. Current health status: ${health_status}" >&2
  return 1
}

# retry_command <timeout> <interval> <command_string>
# Retries a given command string until it succeeds or timeout is reached.
# The command string is executed in a subshell.
retry_command() {
  local timeout="$1"
  local interval="$2"
  local command_string="$3"
  local elapsed=0

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if eval "${command_string}"; then
      return 0
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  return 1
}
