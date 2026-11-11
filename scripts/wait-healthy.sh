#!/usr/bin/env bash
# Usage: ./scripts/wait-healthy.sh --stack <name> [--timeout 300]
# Waits for all containers in a stack to pass healthchecks. Exit codes: 0=healthy, 1=timeout, 2=exited.
set -euo pipefail

STACK=""
TIMEOUT=300
POLL_INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 --stack <name> [--timeout 300]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$STACK" ]]; then
  echo "Error: --stack <name> is required" >&2
  exit 1
fi

COMPOSE_FILE="stacks/${STACK}/docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: Compose file not found at ${COMPOSE_FILE}" >&2
  exit 1
fi

elapsed=0
while (( elapsed < TIMEOUT )); do
  exited_containers=$(docker compose -f "$COMPOSE_FILE" ps --status exited --format '{{.Name}}' 2>/dev/null || true)
  if [[ -n "$exited_containers" ]]; then
    echo "[ERROR] Containers exited unexpectedly in stack '${STACK}': ${exited_containers}" >&2
    for c in $exited_containers; do
      docker logs --tail 50 "$c" 2>&1 || true
    done
    exit 2
  fi

  unhealthy=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}} {{.Health}}' 2>/dev/null | grep -Ev '(healthy|^$)' || true)
  if [[ -z "$unhealthy" ]]; then
    echo "[OK] All containers in stack '${STACK}' are healthy."
    exit 0
  fi

  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

echo "[TIMEOUT] Stack '${STACK}' did not become healthy within ${TIMEOUT}s." >&2
docker compose -f "$COMPOSE_FILE" logs --tail 50 || true
exit 1
