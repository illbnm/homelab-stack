#!/usr/bin/env bash
# =============================================================================
# Wait for Stack to be Healthy
# =============================================================================
set -e

STACK_NAME=""
TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK_NAME="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 --stack <name> [--timeout 300]"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$BASE_DIR/stacks/$STACK_NAME/docker-compose.yml"
if [ "$STACK_NAME" == "base" ]; then
  COMPOSE_FILE="$BASE_DIR/docker-compose.base.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: Compose file $COMPOSE_FILE not found."
  exit 1
fi

echo "Waiting for stack '$STACK_NAME' to be healthy (timeout: ${TIMEOUT}s)..."

END_TIME=$(( SECONDS + TIMEOUT ))

while [ $SECONDS -lt $END_TIME ]; do
  EXITED=$(docker compose -f "$COMPOSE_FILE" ps --status exited -q)
  if [ -n "$EXITED" ]; then
    echo "Error: One or more containers exited prematurely."
    docker compose -f "$COMPOSE_FILE" logs --tail 50
    exit 2
  fi

  ALL_CONTAINERS=$(docker compose -f "$COMPOSE_FILE" ps -q)
  if [ -z "$ALL_CONTAINERS" ]; then
    echo "No containers found for stack."
    sleep 5
    continue
  fi

  ALL_HEALTHY=true
  for cid in $ALL_CONTAINERS; do
    STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")
    if [ "$STATUS" != "healthy" ] && [ "$STATUS" != "running" ]; then
      ALL_HEALTHY=false
      break
    fi
  done

  if $ALL_HEALTHY; then
    echo "Stack '$STACK_NAME' is healthy."
    exit 0
  fi

  sleep 5
done

echo "Timeout waiting for stack '$STACK_NAME' to be healthy."
for cid in $(docker compose -f "$COMPOSE_FILE" ps -q); do
  STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")
  if [ "$STATUS" != "healthy" ] && [ "$STATUS" != "running" ]; then
    NAME=$(docker inspect --format='{{.Name}}' "$cid" | sed 's/^\///')
    echo "Logs for unhealthy container: $NAME"
    docker logs --tail 50 "$cid"
  fi
done

exit 1
