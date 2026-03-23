#!/usr/bin/env bash
# =============================================================================
# Wait for containers to become healthy
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# wait_healthy <container_name> [timeout_seconds=120]
#   Block until a container's healthcheck reports "healthy" or timeout.
#   Returns 0 on healthy, 1 on timeout.
# ---------------------------------------------------------------------------
wait_healthy() {
  local name="${1:?container name required}"
  local timeout="${2:-120}"
  local elapsed=0
  local interval=3
  local status

  while (( elapsed < timeout )); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "missing")

    case "${status}" in
      healthy)
        return 0
        ;;
      unhealthy)
        echo "  WARN: ${name} is unhealthy after ${elapsed}s" >&2
        return 1
        ;;
      missing)
        # Container may not exist yet or has no healthcheck
        ;;
    esac

    sleep "${interval}"
    (( elapsed += interval )) || true
  done

  echo "  TIMEOUT: ${name} not healthy after ${timeout}s (status: ${status})" >&2
  return 1
}

# ---------------------------------------------------------------------------
# wait_healthy_all <timeout_seconds> <container_name...>
#   Wait for multiple containers to become healthy.
# ---------------------------------------------------------------------------
wait_healthy_all() {
  local timeout="${1:?timeout required}"
  shift

  local failed=0
  for container in "$@"; do
    if ! wait_healthy "${container}" "${timeout}"; then
      (( failed++ )) || true
    fi
  done

  return "${failed}"
}

# ---------------------------------------------------------------------------
# wait_stack_healthy <stack_name> [timeout_seconds=180]
#   Wait for all containers in a stack to become healthy.
# ---------------------------------------------------------------------------
wait_stack_healthy() {
  local stack="${1:?stack name required}"
  local timeout="${2:-180}"

  # Source docker helpers if not already loaded
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=tests/lib/docker.sh
  source "${script_dir}/docker.sh"

  local containers
  containers=$(stack_compose "${stack}" ps --format '{{.Name}}' 2>/dev/null || echo "")

  if [[ -z "${containers}" ]]; then
    echo "  WARN: no containers found for stack '${stack}'" >&2
    return 1
  fi

  local failed=0
  while IFS= read -r container; do
    [[ -z "${container}" ]] && continue

    # Check if container has a healthcheck
    local has_hc
    has_hc=$(docker inspect -f '{{if .State.Health}}true{{else}}false{{end}}' \
      "${container}" 2>/dev/null || echo "false")

    if [[ "${has_hc}" == "true" ]]; then
      if ! wait_healthy "${container}" "${timeout}"; then
        (( failed++ )) || true
      fi
    fi
  done <<< "${containers}"

  return "${failed}"
}
