#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Functions
# Helpers for container inspection, health checks, and network tests.
# =============================================================================

# Requires assert.sh to be sourced first.

# ---------------------------------------------------------------------------
# Container checks
# ---------------------------------------------------------------------------

# assert_container_running CONTAINER_NAME
assert_container_running() {
  local name="$1"
  local running
  running=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c "^${name}$" || true)
  if [[ "$running" -ge 1 ]]; then
    _record_pass "Container ${name} is running"
  else
    _record_fail "Container ${name} is running" "container not found or not running"
  fi
}

# assert_container_healthy CONTAINER_NAME
assert_container_healthy() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    _record_skip "Container ${name} is healthy" "container not running"
    return
  fi
  local health
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null)
  case "$health" in
    healthy)
      _record_pass "Container ${name} is healthy"
      ;;
    no-healthcheck)
      _record_pass "Container ${name} is running (no healthcheck defined)"
      ;;
    *)
      _record_fail "Container ${name} is healthy" "status=${health}"
      ;;
  esac
}

# assert_container_not_restarting CONTAINER_NAME
assert_container_not_restarting() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    _record_skip "Container ${name} not restarting" "container not running"
    return
  fi
  local restart_count
  restart_count=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "0")
  if [[ "$restart_count" -le 2 ]]; then
    _record_pass "Container ${name} not restarting (restarts=${restart_count})"
  else
    _record_fail "Container ${name} not restarting" "restart_count=${restart_count}"
  fi
}

# is_container_running CONTAINER_NAME  (returns 0/1, no output)
is_container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

# ---------------------------------------------------------------------------
# Port checks
# ---------------------------------------------------------------------------

# assert_port_open HOST PORT [MESSAGE]
assert_port_open() {
  local host="${1:-localhost}" port="$2" msg="${3:-Port ${2} open on ${1}}"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "connection refused or timed out"
  fi
}

# assert_port_listening PORT [MESSAGE]
# Checks if a port is listening on localhost.
assert_port_listening() {
  local port="$1" msg="${2:-Port ${1} is listening}"
  if nc -z -w3 localhost "$port" 2>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "port not listening"
  fi
}

# ---------------------------------------------------------------------------
# Network checks
# ---------------------------------------------------------------------------

# assert_docker_network_exists NETWORK_NAME
assert_docker_network_exists() {
  local name="$1"
  if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
    _record_pass "Docker network '${name}' exists"
  else
    _record_fail "Docker network '${name}' exists" "network not found"
  fi
}

# assert_container_in_network CONTAINER NETWORK
assert_container_in_network() {
  local container="$1" network="$2"
  if ! is_container_running "$container"; then
    _record_skip "Container ${container} in network ${network}" "container not running"
    return
  fi
  local networks
  networks=$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null)
  if [[ "$networks" == *"$network"* ]]; then
    _record_pass "Container ${container} in network ${network}"
  else
    _record_fail "Container ${container} in network ${network}" "actual networks: ${networks}"
  fi
}

# ---------------------------------------------------------------------------
# Docker Compose checks
# ---------------------------------------------------------------------------

# assert_compose_valid COMPOSE_FILE
# Validates docker compose file syntax.
assert_compose_valid() {
  local file="$1" msg="Compose syntax valid: ${1}"
  if [[ ! -f "$file" ]]; then
    _record_fail "$msg" "file not found"
    return
  fi
  local output
  output=$(docker compose -f "$file" config --quiet 2>&1) && {
    _record_pass "$msg"
  } || {
    _record_fail "$msg" "${output}"
  }
}

# get_compose_services COMPOSE_FILE
# Returns a list of service names defined in a compose file.
get_compose_services() {
  local file="$1"
  docker compose -f "$file" config --services 2>/dev/null
}

# assert_compose_service_has_healthcheck COMPOSE_FILE SERVICE
assert_compose_service_has_healthcheck() {
  local file="$1" service="$2"
  local msg="Service ${service} has healthcheck in ${file##*/}"
  if [[ ! -f "$file" ]]; then
    _record_fail "$msg" "file not found"
    return
  fi
  if grep -A 30 "^\s*${service}:" "$file" | grep -q "healthcheck"; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "no healthcheck defined"
  fi
}

# ---------------------------------------------------------------------------
# Image tag checks
# ---------------------------------------------------------------------------

# assert_no_latest_tags DIR
# Scans compose files in DIR for :latest image tags.
assert_no_latest_tags() {
  local dir="$1" msg="No :latest image tags in ${1}"
  local count
  count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "found ${count} :latest tags"
  fi
}

# ---------------------------------------------------------------------------
# Exec helpers
# ---------------------------------------------------------------------------

# docker_exec CONTAINER CMD...
# Runs a command inside a container, returns output.
docker_exec() {
  local container="$1"; shift
  docker exec "$container" "$@" 2>/dev/null
}

# assert_docker_exec CONTAINER MESSAGE CMD...
# Runs a command inside a container and asserts exit code 0.
assert_docker_exec() {
  local container="$1" msg="$2"; shift 2
  if ! is_container_running "$container"; then
    _record_skip "$msg" "container not running"
    return
  fi
  if docker exec "$container" "$@" &>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "command failed: $*"
  fi
}
