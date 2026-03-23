#!/usr/bin/env bash
# =============================================================================
# HomeLab Test Framework — Docker Utilities
# =============================================================================

_docker_is_running() {
  local name="$1"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"
}

_docker_is_healthy() {
  local name="$1"
  local health
  health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck")
  [[ "$health" == "healthy" || "$health" == "no-healthcheck" ]]
}

_docker_wait_healthy() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0

  if ! _docker_is_running "$name"; then
    return 1
  fi

  while [[ $elapsed -lt $timeout ]]; do
    if _docker_is_healthy "$name"; then
      return 0
    fi
    sleep 2
    ((elapsed += 2))
  done
  return 1
}

_docker_get_ip() {
  local name="$1"
  docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null
}

_docker_get_env() {
  local name="$1" key="$2"
  docker inspect "$name" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
    | grep "^${key}=" | cut -d= -f2- | head -1
}

_docker_exec() {
  local name="$1"
  shift
  docker exec "$name" "$@" 2>/dev/null
}

_docker_container_count() {
  docker ps -q 2>/dev/null | wc -l
}
