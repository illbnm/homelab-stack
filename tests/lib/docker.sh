#!/usr/bin/env bash
# =============================================================================
# Docker Helper Functions for HomeLab Integration Tests
#
# NOTE: Tests assume that compose files set explicit `container_name:` values
# for each service. Functions like container_ip, container_exec, and the
# assert_container_* helpers all reference containers by their explicit name,
# not by the Compose-generated name (<project>-<service>-<n>).
# =============================================================================
[[ -n "${_LIB_DOCKER_LOADED:-}" ]] && return 0
_LIB_DOCKER_LOADED=1

set -euo pipefail

# Root of the homelab-stack repository
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# ---------------------------------------------------------------------------
# stack_compose <stack_name> [compose args...]
#   Run docker compose for a given stack.
# ---------------------------------------------------------------------------
stack_compose() {
  local stack="${1:?stack name required}"
  shift
  local compose_dir="${REPO_ROOT}/stacks/${stack}"

  if [[ ! -d "${compose_dir}" ]]; then
    echo "ERROR: stack directory not found: ${compose_dir}" >&2
    return 1
  fi

  docker compose -f "${compose_dir}/docker-compose.yml" \
    --project-directory "${compose_dir}" \
    "$@"
}

# ---------------------------------------------------------------------------
# stack_up <stack_name>
#   Bring a stack up in detached mode.
# ---------------------------------------------------------------------------
stack_up() {
  local stack="${1:?stack name required}"
  stack_compose "${stack}" up -d --quiet-pull 2>/dev/null || \
    stack_compose "${stack}" up -d
}

# ---------------------------------------------------------------------------
# stack_down <stack_name>
#   Tear down a stack and remove volumes.
# ---------------------------------------------------------------------------
stack_down() {
  local stack="${1:?stack name required}"
  stack_compose "${stack}" down -v --remove-orphans 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# stack_services <stack_name>
#   List service names defined in the stack's compose file.
# ---------------------------------------------------------------------------
stack_services() {
  local stack="${1:?stack name required}"
  stack_compose "${stack}" config --services 2>/dev/null
}

# ---------------------------------------------------------------------------
# container_ip <container_name>
#   Get the IP address of a container on its first network.
# ---------------------------------------------------------------------------
container_ip() {
  local name="${1:?container name required}"
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    "${name}" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# container_port <container_name> <internal_port>
#   Get the host-mapped port for an internal container port.
# ---------------------------------------------------------------------------
container_port() {
  local name="${1:?container name required}"
  local port="${2:?port required}"
  docker port "${name}" "${port}" 2>/dev/null | head -1 | cut -d: -f2 || echo ""
}

# ---------------------------------------------------------------------------
# container_logs <container_name> [lines=50]
#   Tail the last N lines of a container's logs.
# ---------------------------------------------------------------------------
container_logs() {
  local name="${1:?container name required}"
  local lines="${2:-50}"
  docker logs --tail "${lines}" "${name}" 2>&1
}

# ---------------------------------------------------------------------------
# container_exec <container_name> <command...>
#   Execute a command inside a running container.
# ---------------------------------------------------------------------------
container_exec() {
  local name="${1:?container name required}"
  shift
  docker exec "${name}" "$@"
}

# ---------------------------------------------------------------------------
# compose_config_valid <stack_name>
#   Validates compose config by running `docker compose config --quiet`.
#   Returns 0 if valid, 1 otherwise.
# ---------------------------------------------------------------------------
compose_config_valid() {
  local stack="${1:?stack name required}"
  stack_compose "${stack}" config --quiet 2>/dev/null
}

# ---------------------------------------------------------------------------
# has_healthcheck <stack_name> <service_name>
#   Check if a service has a healthcheck defined in its compose file.
# ---------------------------------------------------------------------------
has_healthcheck() {
  local stack="${1:?stack name required}"
  local service="${2:?service name required}"
  local hc
  hc=$(stack_compose "${stack}" config 2>/dev/null | \
    yq -r ".services.\"${service}\".healthcheck.test // empty" 2>/dev/null || \
    stack_compose "${stack}" config 2>/dev/null | \
    python3 -c "import sys,json,yaml; d=yaml.safe_load(sys.stdin); print(d.get('services',{}).get('${service}',{}).get('healthcheck',{}).get('test',''))" 2>/dev/null || \
    echo "")

  if [[ -n "${hc}" ]]; then
    return 0
  fi

  # Fallback: grep the compose file directly
  local compose_file="${REPO_ROOT}/stacks/${stack}/docker-compose.yml"
  if grep -A2 "healthcheck:" "${compose_file}" 2>/dev/null | grep -q "test:"; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# network_exists <network_name>
#   Check if a Docker network exists.
# ---------------------------------------------------------------------------
network_exists() {
  local name="${1:?network name required}"
  docker network inspect "${name}" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# ensure_network <network_name>
#   Create a Docker network if it doesn't already exist.
# ---------------------------------------------------------------------------
ensure_network() {
  local name="${1:?network name required}"
  if ! network_exists "${name}"; then
    docker network create "${name}" >/dev/null 2>&1
  fi
}
