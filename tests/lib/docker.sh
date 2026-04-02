#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Helper Functions
# Utility functions for Docker container management
# =============================================================================

set -euo pipefail

# =============================================================================
# Container Status Functions
# =============================================================================

get_container_status() {
  local name="$1"
  docker ps -a --filter "name=$name" --format "{{.Status}}" 2>/dev/null || echo "not found"
}

is_container_running() {
  local name="$1"
  docker ps --filter "name=$name" --filter "status=running" --format "{{.Names}}" | grep -q "^${name}$"
}

is_container_healthy() {
  local name="$1"
  docker ps --filter "name=$name" --format "{{.Status}}" | grep -q "(healthy)"
}

get_container_ip() {
  local name="$1"
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null || echo ""
}

get_container_port() {
  local name="$1"
  local port="$2"
  docker port "$name" "$port" 2>/dev/null | cut -d: -f2 || echo ""
}

# =============================================================================
# Container Management Functions
# =============================================================================

restart_container() {
  local name="$1"
  docker restart "$name" > /dev/null 2>&1
}

stop_container() {
  local name="$1"
  docker stop "$name" > /dev/null 2>&1
}

start_container() {
  local name="$1"
  docker start "$name" > /dev/null 2>&1
}

remove_container() {
  local name="$1"
  docker rm -f "$name" > /dev/null 2>&1
}

# =============================================================================
# Compose Functions
# =============================================================================

compose_up() {
  local compose_file="$1"
  docker compose -f "$compose_file" up -d > /dev/null 2>&1
}

compose_down() {
  local compose_file="$1"
  docker compose -f "$compose_file" down > /dev/null 2>&1
}

compose_ps() {
  local compose_file="$1"
  docker compose -f "$compose_file" ps
}

get_compose_services() {
  local compose_file="$1"
  docker compose -f "$compose_file" config --services
}

# =============================================================================
# Image Functions
# =============================================================================

pull_image() {
  local image="$1"
  docker pull "$image" > /dev/null 2>&1
}

image_exists() {
  local image="$1"
  docker image inspect "$image" > /dev/null 2>&1
}

# =============================================================================
# Network Functions
# =============================================================================

network_exists() {
  local name="$1"
  docker network ls --filter "name=$name" --format "{{.Name}}" | grep -q "^${name}$"
}

create_network() {
  local name="$1"
  docker network create "$name" > /dev/null 2>&1
}

container_in_network() {
  local container="$1"
  local network="$2"
  docker network inspect "$network" | jq -r ".[0].Containers[].Name" | grep -q "^${container}$"
}

# =============================================================================
# Volume Functions
# =============================================================================

volume_exists() {
  local name="$1"
  docker volume ls --filter "name=$name" --format "{{.Name}}" | grep -q "^${name}$"
}

create_volume() {
  local name="$1"
  docker volume create "$name" > /dev/null 2>&1
}

# =============================================================================
# Log Functions
# =============================================================================

get_container_logs() {
  local name="$1"
  local lines="${2:-100}"
  docker logs --tail "$lines" "$name" 2>&1
}

# =============================================================================
# Health Check Functions
# =============================================================================

wait_for_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local interval="${3:-2}"
  
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if is_container_healthy "$name"; then
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  
  return 1
}

wait_for_all_healthy() {
  local compose_file="$1"
  local timeout="${2:-120}"
  
  local services
  services=$(get_compose_services "$compose_file")
  
  for service in $services; do
    if ! wait_for_healthy "$service" "$timeout"; then
      echo "Container $service not healthy after ${timeout}s"
      return 1
    fi
  done
  
  return 0
}
