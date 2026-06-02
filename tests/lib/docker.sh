#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Functions
# =============================================================================
set -euo pipefail

COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"

get_compose_file() {
  local stack="$1"
  local dir="$STACKS_DIR/$stack"
  if [[ -f "$dir/docker-compose.yml" ]]; then
    echo "$dir/docker-compose.yml"
    return 0
  fi
  echo ""
  return 1
}

wait_for_healthy() {
  local container="$1" timeout="${2:-60}" interval="${3:-2}"
  local waited=0
  while [[ $waited -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo 'no-healthcheck')
    if [[ "$health" == "healthy" ]]; then
      return 0
    fi
    if [[ "$health" == "unhealthy" ]]; then
      return 1
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done
  return 1
}

wait_for_port() {
  local host="$1" port="$2" timeout="${3:-30}" interval="${4:-1}"
  local waited=0
  while [[ $waited -lt $timeout ]]; do
    if nc -z -w1 "$host" "$port" 2>/dev/null; then
      return 0
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done
  return 1
}

list_containers_in_stack() {
  local stack="$1"
  local compose_file
  compose_file=$(get_compose_file "$stack")
  if [[ -z "$compose_file" ]]; then
    return 1
  fi
  $COMPOSE_BIN -f "$compose_file" ps -q 2>/dev/null | while read -r id; do
    docker inspect --format '{{.Name}}' "$id" 2>/dev/null | sed 's|^/||'
  done
}

compose_config_validate() {
  local compose_file="$1"
  local result
  result=$($COMPOSE_BIN -f "$compose_file" config --quiet 2>&1)
  return $?
}

get_all_services() {
  local compose_file="$1"
  $COMPOSE_BIN -f "$compose_file" config --services 2>/dev/null
}

container_logs_tail() {
  local container="$1" lines="${2:-30}"
  docker logs --tail="$lines" "$container" 2>/dev/null
}

image_supports_arm64() {
  local image="$1"
  docker buildx imagetools inspect "$image" 2>/dev/null | grep -q 'linux/arm64' && return 0
  return 1
}
