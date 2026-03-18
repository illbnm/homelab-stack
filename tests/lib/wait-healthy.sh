#!/usr/bin/env bash
# =============================================================================
# Wait for all containers in the current compose project to be healthy.
#
# Usage: ./wait-healthy.sh [--timeout 120]
# =============================================================================
set -euo pipefail

TIMEOUT=120

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) shift; TIMEOUT="${1:-120}" ;;
    *) ;;
  esac
  shift
done

echo "Waiting up to ${TIMEOUT}s for all containers to be healthy..."

for ((i = 0; i < TIMEOUT; i++)); do
  # Get all containers with health checks
  ALL_HEALTHY=true

  while IFS= read -r container; do
    [[ -z "${container}" ]] && continue
    health=$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null) || continue
    if [[ "${health}" != "healthy" ]]; then
      ALL_HEALTHY=false
      break
    fi
  done < <(docker ps --format '{{.Names}}' 2>/dev/null)

  if ${ALL_HEALTHY}; then
    echo "All containers healthy after ${i}s"
    exit 0
  fi

  sleep 1
done

echo "ERROR: Not all containers healthy after ${TIMEOUT}s" >&2
docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null
exit 1
