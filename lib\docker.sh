#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Functions
# Provides helpers for inspecting containers, volumes, networks and compose stacks
# =============================================================================

# shellcheck shell=bash

[[ -n "${_DOCKER_SH_LOADED:-}" ]] && return 0
_DOCKER_SH_LOADED=1

# ---------------------------------------------------------------------------
# Container state helpers
# ---------------------------------------------------------------------------

# docker_container_running <name> → exit 0 if running
docker_container_running() {
  local name="$1"
  local state
  state=$(docker inspect --format '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
  [[ "$state" == "true" ]]
}

# docker_container_status <name> → prints status string
docker_container_status() {
  local name="$1"
  docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found"
}

# docker_container_health <name> → prints health string (healthy/unhealthy/starting/none)
docker_container_health() {
  local name="$1"
  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "unknown"
}

# docker_container_ip <name> [network] → prints container IP
docker_container_ip() {
  local name="$1"
  local network="${2:-}"
  if [[ -n "$network" ]]; then
    docker inspect --format "{{(index .NetworkSettings.Networks \"${network}\").IPAddress}}" "$name" 2>/dev/null || echo ""
  else
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null | head -1 || echo ""
  fi
}

# docker_container_port <name> <container_port/proto> → prints host port mapping
docker_container_port() {
  local name="$1"
  local container_port="$2"
  docker inspect --format "{{(index .NetworkSettings.Ports \"${container_port}\") }}" "$name" 2>/dev/null \
    | grep -oP 'HostPort:\K[0-9]+' | head -1 || echo ""
}

# docker_container_uptime_seconds <name> → approximate uptime in seconds
docker_container_uptime_seconds() {
  local name="$1"
  local started
  started=$(docker inspect --format '{{.State.StartedAt}}' "$name" 2>/dev/null || echo "")
  if [[ -z "$started" ]]; then echo 0; return; fi
  local started_epoch now_epoch
  started_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started%.*}" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( now_epoch - started_epoch ))
}

# docker_container_restart_count <name>
docker_container_restart_count() {
  local name="$1"
  docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "0"
}

# docker_list_running → prints names of all running containers
docker_list_running() {
  docker ps --format '{{.Names}}' 2>/dev/null || true
}

# docker_list_by_label <label_key> <label_value>
docker_list_by_label() {
  local key="$1"
  local value="$2"
  docker ps --filter "label=${key}=${value}" --format '{{.Names}}' 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Volume helpers
# ---------------------------------------------------------------------------

# docker_volume_exists <volume_name>
docker_volume_exists() {
  local name="$1"
  docker volume inspect "$name" &>/dev/null
}

# docker_volume_driver <volume_name>
docker_volume_driver() {
  local name="$1"
  docker volume inspect --format '{{.Driver}}' "$name" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

# docker_network_exists <network_name>
docker_network_exists() {
  local name="$1"
  docker network inspect "$name" &>/dev/null
}

# docker_network_driver <network_name>
docker_network_driver() {
  local name="$1"
  docker network inspect --format '{{.Driver}}' "$name" 2>/dev/null || echo ""
}

# docker_containers_can_communicate <container_a> <container_b> [port]
# Test connectivity by running ping or nc from container_a to container_b
docker_containers_can_communicate() {
  local container_a="$1"
  local container_b="$2"
  local port="${3:-}"

  if [[ -n "$port" ]]; then
    docker exec "$container_a" sh -c \
      "nc -z -w5 ${container_b} ${port} 2>/dev/null || nc -z -w5 \$(getent hosts ${container_b} | awk '{print \$1}') ${port} 2>/dev/null" \
      2>/dev/null
  else
    docker exec "$container_a" sh -c \
      "ping -c1 -W3 ${container_b} 2>/dev/null || ping -c1 -W3 \$(getent hosts ${container_b} | awk '{print \$1}') 2>/dev/null" \
      2>/dev/null
  fi
}

# ---------------------------------------------------------------------------
# Compose helpers
# ---------------------------------------------------------------------------

# docker_compose_ps <compose_file> → prints service statuses
docker_compose_ps() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps 2>/dev/null || true
}

# docker_compose_running_services <compose_file> → list of running service names
docker_compose_running_services() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null || true
}

# docker_compose_up <compose_file> [extra_args...]
docker_compose_up() {
  local compose_file="$1"
  shift
  docker compose -f "$compose_file" up -d "$@"
}

# docker_compose_down <compose_file> [extra_args...]
docker_compose_down() {
  local compose_file="$1"
  shift
  docker compose -f "$compose_file" down "$@"
}

# ---------------------------------------------------------------------------
# System checks
# ---------------------------------------------------------------------------

# docker_check_requirements → exit 1 if Docker daemon not accessible
docker_check_requirements() {
  if ! command -v docker &>/dev/null; then
    echo "ERROR: 'docker' command not found in PATH" >&2
    return 1
  fi
  if ! docker info &>/dev/null; then
    echo "ERROR: Docker daemon is not accessible (is it running?)" >&2
    return 1
  fi
  return 0
}

# docker_check_compose_plugin → exit 1 if 'docker compose' v2 not available
docker_check_compose_plugin() {
  if ! docker compose version &>/dev/null; then
    echo "ERROR: Docker Compose plugin v2 not available. Run: apt install docker-compose-plugin" >&2
    return 1
  fi
  return 0
}

# docker_daemon_info → prints daemon version info
docker_daemon_info() {
  docker version --format 'Docker {{.Server.Version}} (API {{.Server.APIVersion}})' 2>/dev/null || echo "unknown"
}
