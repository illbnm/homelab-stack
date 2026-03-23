#!/usr/bin/env bash
# =============================================================================
# Wait for containers to be healthy
# Usage: wait-healthy.sh [--timeout 120] [--container name]
# =============================================================================
set -euo pipefail

TIMEOUT=120
TARGET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --container) TARGET="$2"; shift 2 ;;
    *) shift ;;
  esac
done

wait_container() {
  local name="$1"
  local elapsed=0
  echo -n "Waiting for $name to be healthy"
  while [[ $elapsed -lt $TIMEOUT ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "not-found")
    if [[ "$health" == "healthy" ]]; then
      echo " ✓ (${elapsed}s)"
      return 0
    elif [[ "$health" == "not-found" ]]; then
      # No healthcheck, just check if running
      if docker ps --format '{{.Names}}' | grep -qx "$name"; then
        echo " ✓ (running, no healthcheck, ${elapsed}s)"
        return 0
      fi
    fi
    echo -n "."
    sleep 3
    ((elapsed += 3))
  done
  echo " ✗ (timeout after ${TIMEOUT}s)"
  return 1
}

if [[ -n "$TARGET" ]]; then
  wait_container "$TARGET"
else
  # Wait for all running containers
  FAILED=0
  for name in $(docker ps --format '{{.Names}}'); do
    wait_container "$name" || ((FAILED++))
  done
  echo ""
  echo "Done. $FAILED container(s) timed out."
  [[ $FAILED -eq 0 ]]
fi
