#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — wait-healthy.sh
# Wait for all containers in a compose file to become healthy
# Usage: ./tests/lib/wait-healthy.sh --timeout 120 [compose_file]
# =============================================================================
set -euo pipefail

TIMEOUT=120
COMPOSE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) COMPOSE_FILE="$1"; shift ;;
  esac
done

if [[ -z "$COMPOSE_FILE" ]]; then
  echo "Usage: $0 --timeout <seconds> <compose_file>"
  exit 1
fi

COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"
CONTAINERS=$($COMPOSE_BIN -f "$COMPOSE_FILE" ps -q 2>/dev/null || true)

if [[ -z "$CONTAINERS" ]]; then
  echo "No containers found for $COMPOSE_FILE"
  exit 1
fi

echo "Waiting up to ${TIMEOUT}s for containers to become healthy..."
ELAPSED=0
INTERVAL=3

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  ALL_HEALTHY=true
  for CID in $CONTAINERS; do
    NAME=$(docker inspect --format '{{.Name}}' "$CID" 2>/dev/null | sed 's|^/||' || echo "unknown")
    HEALTH=$(docker inspect --format '{{.State.Health.Status}}' "$CID" 2>/dev/null || echo 'no-healthcheck')
    if [[ "$HEALTH" != "healthy" ]] && [[ "$HEALTH" != "no-healthcheck" ]]; then
      ALL_HEALTHY=false
    fi
  done
  if $ALL_HEALTHY; then
    echo "All containers healthy!"
    exit 0
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "  ... $ELAPSED/${TIMEOUT}s"
done

echo "Timeout! Not all containers became healthy."
exit 1
