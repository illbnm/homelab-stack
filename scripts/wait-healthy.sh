#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — Wait for Docker Compose services to become healthy
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "  ${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "  ${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
log_fail()  { echo -e "  ${RED}[FAIL]${NC} $*"; }

TIMEOUT=300
POLL_INTERVAL=5
STACK_NAME=""
COMPOSE_FILE=""
LOG_LINES=50

usage() {
  cat <<EOF
Usage: $0 --stack <name> [--timeout <sec>] [--compose <file>]

Wait for all containers in a stack to pass health checks.

Options:
  --stack <name>       Stack name (looks for stacks/<name>/docker-compose*.yml)
  --compose <file>     Path to docker-compose file (overrides --stack)
  --timeout <sec>      Max seconds to wait (default: 300)
  --interval <sec>    Poll interval (default: 5)
  --logs <n>           Print last N log lines on failure (default: 50)

Exit codes:
  0   All containers healthy
  1   Timeout
  2   Container exited (not running)
  3   No stack specified

Examples:
  $0 --stack monitoring --timeout 600
  $0 --compose /path/to/docker-compose.yml --timeout 120
EOF
  exit 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)     STACK_NAME="$2"; shift 2 ;;
    --compose)   COMPOSE_FILE="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --interval)  POLL_INTERVAL="$2"; shift 2 ;;
    --logs)      LOG_LINES="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

if [[ -z "$STACK_NAME" && -z "$COMPOSE_FILE" ]]; then
  usage
fi

# Resolve compose file
if [[ -n "$COMPOSE_FILE" ]]; then
  COMPOSE_ARGS=("-f" "$COMPOSE_FILE")
elif [[ -n "$STACK_NAME" ]]; then
  if [[ -f "$SCRIPT_DIR/../stacks/$STACK_NAME/docker-compose.local.yml" ]]; then
    COMPOSE_FILE="$SCRIPT_DIR/../stacks/$STACK_NAME/docker-compose.local.yml"
  elif [[ -f "$SCRIPT_DIR/../stacks/$STACK_NAME/docker-compose.yml" ]]; then
    COMPOSE_FILE="$SCRIPT_DIR/../stacks/$STACK_NAME/docker-compose.yml"
  else
    log_fail "Stack not found: $STACK_NAME"
    exit 3
  fi
  COMPOSE_ARGS=("-f" "$COMPOSE_FILE")
fi

cd "$(dirname "$COMPOSE_FILE")"
COMPOSE_DIR="$(pwd)"

echo ""
echo "=== Waiting for stack to be healthy ==="
echo "  Compose: $COMPOSE_FILE"
echo "  Timeout: ${TIMEOUT}s"
echo "  Interval: ${POLL_INTERVAL}s"
echo ""

get_container_states() {
  docker compose "${COMPOSE_ARGS[@]}" ps --format json 2>/dev/null | \
    python3 -c "
import json,sys
for line in sys.stdin:
    try:
        c = json.loads(line)
        name = c.get('Service', c.get('Name', '?'))
        state = c.get('State', '?')
        health = c.get('Health', '-')
        print(f'{name}|{state}|{health}')
    except: pass
" 2>/dev/null || docker compose "${COMPOSE_ARGS[@]}" ps 2>/dev/null | tail -n +3 | \
    awk '{print $1"|"$3"|"$4}'
}

wait_for_healthy() {
  local elapsed=0
  local interval=$POLL_INTERVAL

  while [[ $elapsed -lt $TIMEOUT ]]; do
    local states
    states=$(get_container_states)

    if [[ -z "$states" ]]; then
      log_warn "No containers found for this stack"
      return 2
    fi

    local all_healthy=true
    local any_exit=false
    local unhealthy=()

    while IFS='|' read -r name state health; do
      [[ -z "$name" ]] && continue

      # Normalize state
      state=$(echo "$state" | tr '[:upper:]' '[:lower:]')

      if [[ "$state" == "running" ]]; then
        if [[ "$health" == "healthy" || "$health" == "-" ]]; then
          echo -ne "  ${GREEN}✓${NC} $name (healthy)\r"
        else
          echo -ne "  ${YELLOW}⋯${NC} $name (starting)\r"
          all_healthy=false
        fi
      elif [[ "$state" == "exited" || "$state" == "dead" || "$state" == "created" ]]; then
        any_exit=true
        unhealthy+=("$name:$state")
        echo -ne "  ${RED}✗${NC} $name ($state)\r"
      else
        echo -ne "  ${YELLOW}⋯${NC} $name ($state)\r"
        all_healthy=false
      fi
    done <<< "$states"

    echo -ne "\033[K"

    if [[ "$all_healthy" == "true" ]]; then
      echo ""
      log_ok "All containers healthy after ${elapsed}s"
      return 0
    fi

    if [[ "$any_exit" == "true" ]]; then
      echo ""
      log_fail "Some containers have exited:"
      for u in "${unhealthy[@]}"; do
        IFS=':' read -r name state <<< "$u"
        echo "  ✗ $name — $state"
      done
      return 2
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
    echo -ne "  Waiting... ${elapsed}s / ${TIMEOUT}s  \r"
  done

  echo ""
  log_fail "Timeout after ${TIMEOUT}s"
  echo ""
  log_warn "Container states at timeout:"
  get_container_states | while IFS='|' read -r name state health; do
    [[ -z "$name" ]] && continue
    echo "  • $name | $state | $health"
  done

  echo ""
  log_warn "Recent logs for unhealthy containers:"
  get_container_states | while IFS='|' read -r name state health; do
    [[ -z "$name" ]] && continue
    state=$(echo "$state" | tr '[:upper:]' '[:lower:]')
    if [[ "$state" != "running" || "$health" != "healthy" ]]; then
      echo ""
      echo "=== Logs: $name ==="
      docker compose "${COMPOSE_ARGS[@]}" logs --tail="$LOG_LINES" "$name" 2>&1 | tail -"$LOG_LINES"
    fi
  done

  return 1
}

wait_for_healthy
exit $?
