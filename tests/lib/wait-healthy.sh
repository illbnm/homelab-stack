#!/usr/bin/env bash
# ==============================================================================
# tests/lib/wait-healthy.sh — Polls container health status with timeout
# ==============================================================================

wait_for_container_healthy() {
  local container="$1"
  local timeout_sec="${2:-120}"
  if [[ "${HOMELAB_TEST_STATIC:-false}" == "true" ]]; then
    return 0
  fi
  local elapsed=0
  while [[ "$elapsed" -lt "$timeout_sec" ]]; do
    local status
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}healthy{{end}}' "$container" 2>/dev/null || echo "starting")"
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  return 1
}
