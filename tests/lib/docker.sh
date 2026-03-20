#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Functions
# Helpers for container inspection, health checks, and Docker operations.
# =============================================================================

# Source assertion library (if not already loaded)
if ! declare -f _record_result &>/dev/null; then
  source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"
fi

# ---------------------------------------------------------------------------
# Container checks
# ---------------------------------------------------------------------------

# is_container_running NAME
# Returns 0 if running, 1 otherwise
is_container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

# get_container_health NAME
# Returns: healthy, unhealthy, starting, none, or not-running
get_container_health() {
  local name="$1"
  if ! is_container_running "$name"; then
    echo "not-running"
    return
  fi
  local health
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "unknown")
  echo "$health"
}

# get_container_image NAME
# Returns the image name:tag of a running container
get_container_image() {
  docker inspect --format '{{.Config.Image}}' "$1" 2>/dev/null || echo ""
}

# get_container_uptime_seconds NAME
# Returns container uptime in seconds
get_container_uptime_seconds() {
  local started
  started=$(docker inspect --format '{{.State.StartedAt}}' "$1" 2>/dev/null || echo "")
  if [[ -z "$started" ]]; then
    echo 0
    return
  fi
  local start_epoch now_epoch
  start_epoch=$(date -d "$started" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${started%%.*}" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( now_epoch - start_epoch ))
}

# ---------------------------------------------------------------------------
# Assertion wrappers for containers
# ---------------------------------------------------------------------------

# assert_container_running NAME
assert_container_running() {
  local name="$1"
  if is_container_running "$name"; then
    _record_result pass "Container '$name' is running"
  else
    _record_result fail "Container '$name' is running" "container not found or stopped"
  fi
}

# assert_container_healthy NAME
assert_container_healthy() {
  local name="$1"
  local health
  health=$(get_container_health "$name")
  case "$health" in
    healthy)
      _record_result pass "Container '$name' is healthy"
      ;;
    none)
      _record_result pass "Container '$name' is healthy" "no healthcheck defined (running OK)"
      ;;
    not-running)
      _record_result fail "Container '$name' is healthy" "container not running"
      ;;
    *)
      _record_result fail "Container '$name' is healthy" "status: $health"
      ;;
  esac
}

# assert_container_not_restarting NAME
assert_container_not_restarting() {
  local name="$1"
  local restarts
  restarts=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "-1")
  if [[ "$restarts" -le 2 ]]; then
    _record_result pass "Container '$name' not restart-looping" "restarts: $restarts"
  else
    _record_result fail "Container '$name' not restart-looping" "restart count: $restarts"
  fi
}

# assert_container_image_not_latest NAME
assert_container_image_not_latest() {
  local name="$1"
  local image
  image=$(get_container_image "$name")
  if [[ "$image" == *":latest" || "$image" != *":"* ]]; then
    _record_result fail "Container '$name' uses pinned image tag" "image: $image"
  else
    _record_result pass "Container '$name' uses pinned image tag" "image: $image"
  fi
}

# ---------------------------------------------------------------------------
# Port checks
# ---------------------------------------------------------------------------

# is_port_open HOST PORT [TIMEOUT]
is_port_open() {
  local host="${1:-localhost}" port="$2" timeout="${3:-3}"
  nc -z -w"$timeout" "$host" "$port" 2>/dev/null
}

# assert_port_open HOST PORT [MESSAGE]
assert_port_open() {
  local host="$1" port="$2" msg="${3:-Port $2 open on $1}"
  if is_port_open "$host" "$port"; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "port not reachable"
  fi
}

# ---------------------------------------------------------------------------
# Docker Compose helpers
# ---------------------------------------------------------------------------

# compose_config_valid FILE
# Returns 0 if compose file is valid
compose_config_valid() {
  docker compose -f "$1" config --quiet 2>&1
}

# get_compose_services FILE
# Lists service names defined in a compose file
get_compose_services() {
  docker compose -f "$1" config --services 2>/dev/null
}

# get_compose_images FILE
# Lists image:tag pairs from a compose file
get_compose_images() {
  docker compose -f "$1" config 2>/dev/null | grep -E '^\s+image:' | awk '{print $2}'
}

# ---------------------------------------------------------------------------
# Network checks
# ---------------------------------------------------------------------------

# docker_network_exists NAME
docker_network_exists() {
  docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${1}$"
}

# assert_network_exists NAME
assert_network_exists() {
  local name="$1"
  if docker_network_exists "$name"; then
    _record_result pass "Docker network '$name' exists"
  else
    _record_result fail "Docker network '$name' exists" "network not found"
  fi
}

# container_on_network CONTAINER NETWORK
container_on_network() {
  docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$1" 2>/dev/null | grep -q "$2"
}

# assert_container_on_network CONTAINER NETWORK
assert_container_on_network() {
  local container="$1" network="$2"
  if container_on_network "$container" "$network"; then
    _record_result pass "Container '$container' on network '$network'"
  else
    _record_result fail "Container '$container' on network '$network'" "not connected"
  fi
}

# ---------------------------------------------------------------------------
# Volume checks
# ---------------------------------------------------------------------------

# docker_volume_exists NAME
docker_volume_exists() {
  docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "$1"
}

# ---------------------------------------------------------------------------
# Exec helpers
# ---------------------------------------------------------------------------

# docker_exec CONTAINER COMMAND...
# Runs a command inside a container, returns output
docker_exec() {
  local container="$1"
  shift
  docker exec "$container" "$@" 2>/dev/null
}

# require_container NAME
# Skips remaining tests if container is not running
require_container() {
  local name="$1"
  if ! is_container_running "$name"; then
    skip_test "Container '$name' required but not running"
    return 1
  fi
  return 0
}
