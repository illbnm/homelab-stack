#!/usr/bin/env bash
set -u

STACK_NAME=""
TIMEOUT=300
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK_NAME="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 --stack <name> [--timeout 300]"
  exit 1
fi

echo "Waiting for stack '$STACK_NAME' containers to achieve healthy status (timeout: ${TIMEOUT}s)..."

ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  UNHEALTHY=0
  RUNNING=0

  # Get containers for stack
  CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=$STACK_NAME" -q)
  if [ -z "$CONTAINERS" ]; then
    CONTAINERS=$(docker ps --format "{{.ID}} {{.Names}}" | grep "$STACK_NAME" | awk '{print $1}' || true)
  fi

  if [ -z "$CONTAINERS" ]; then
    echo "No containers found running for stack '$STACK_NAME'."
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
    continue
  fi

  for cid in $CONTAINERS; do
    RUNNING=$((RUNNING + 1))
    STATUS=$(docker inspect --format='{{json .State.Health.Status}}' "$cid" 2>/dev/null || echo '"none"')
    STATE=$(docker inspect --format='{{.State.Status}}' "$cid" 2>/dev/null || echo 'unknown')

    if [ "$STATE" = "exited" ] || [ "$STATE" = "dead" ]; then
      echo "❌ Container $cid has exited or died!"
      docker logs --tail 50 "$cid"
      exit 2
    fi

    if [ "$STATUS" = '"unhealthy"' ] || [ "$STATUS" = '"starting"' ]; then
      UNHEALTHY=$((UNHEALTHY + 1))
    fi
  done

  if [ "$UNHEALTHY" -eq 0 ] && [ "$RUNNING" -gt 0 ]; then
    echo " [SUCCESS] All $RUNNING containers in stack '$STACK_NAME' are healthy! (Took ${ELAPSED}s)"
    exit 0
  fi

  printf "  Waiting... (%ds/%ds) — %d containers still starting/unhealthy\n" "$ELAPSED" "$TIMEOUT" "$UNHEALTHY"
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo " [TIMEOUT] Stack '$STACK_NAME' timed out after ${TIMEOUT}s."
for cid in $CONTAINERS; do
  NAME=$(docker inspect --format='{{.Name}}' "$cid")
  echo "--- Tail Logs for $NAME ---"
  docker logs --tail 50 "$cid" || true
done
exit 1
