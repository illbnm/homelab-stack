#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — 等待所有容器健康检查通过
#
# Usage:
#   ./scripts/wait-healthy.sh --stack <name> [--timeout 300]
# =============================================================================

set -euo pipefail

STACK=""
TIMEOUT=300
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)   STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *)         echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$STACK" ]] && { echo "Usage: $0 --stack <name> [--timeout 300]"; exit 1; }

COMPOSE_FILE="stacks/${STACK}/docker-compose.yml"
[[ ! -f "$COMPOSE_FILE" ]] && { echo "Not found: ${COMPOSE_FILE}"; exit 1; }

echo "[wait] Waiting for stack '${STACK}' to be healthy (timeout: ${TIMEOUT}s)..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  unhealthy=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | \
    python3 -c "
import sys, json
for line in sys.stdin:
    try:
        c = json.loads(line)
        h = c.get('Health', c.get('health', ''))
        if h and h != 'healthy':
            print(f\"  {c.get('Name', c.get('name', '?'))}: {h}\")
    except: pass
" 2>/dev/null)

  if [[ -z "$unhealthy" ]]; then
    echo "[wait] ✅ All containers healthy! (${elapsed}s)"
    exit 0
  fi

  echo "[wait] (${elapsed}s) Waiting..."
  echo "$unhealthy"
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

# Timeout — print logs
echo ""
echo "[wait] ❌ Timeout after ${TIMEOUT}s. Unhealthy containers:"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null

echo ""
echo "[wait] Last 50 lines of unhealthy container logs:"
docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | while read -r id; do
  local name=$(docker inspect --format '{{.Name}}' "$id" 2>/dev/null | tr -d '/')
  local health=$(docker inspect --format '{{.State.Health.Status}}' "$id" 2>/dev/null || echo "none")
  if [[ "$health" != "healthy" && "$health" != "none" ]]; then
    echo "--- ${name} (${health}) ---"
    docker logs --tail 50 "$id" 2>&1
    echo ""
  fi
done

exit 1
