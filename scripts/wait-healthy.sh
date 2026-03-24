#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — 等待容器健康检查通过
# Waits for all containers in a stack to report healthy status.
#
# Usage:
#   ./scripts/wait-healthy.sh --stack monitoring --timeout 300
#   ./scripts/wait-healthy.sh --stack base
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

STACK=""
TIMEOUT=300
INTERVAL=5

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 --stack <name> [--timeout <seconds>]"
  echo ""
  echo "  --stack    Stack name (e.g., base, monitoring, sso)"
  echo "  --timeout  Max wait time in seconds (default: 300)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)   STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *)         usage ;;
  esac
done

[[ -z "$STACK" ]] && usage

STACK_DIR="$PROJECT_DIR/stacks/$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
  log_error "Stack directory not found: $STACK_DIR"
  exit 2
fi

# ---------------------------------------------------------------------------
# Get containers for this stack
# ---------------------------------------------------------------------------
get_stack_containers() {
  docker compose -f "$STACK_DIR/docker-compose.yml" ps --format json 2>/dev/null \
    | jq -r '.Name // .name // empty' 2>/dev/null \
    || docker compose -f "$STACK_DIR/docker-compose.yml" ps -q 2>/dev/null
}

# ---------------------------------------------------------------------------
# Check health of a single container
# Returns: healthy, unhealthy, starting, none (no healthcheck), exited
# ---------------------------------------------------------------------------
container_health() {
  local container="$1"
  local state
  state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "missing")

  if [[ "$state" == "exited" || "$state" == "dead" || "$state" == "missing" ]]; then
    echo "exited"
    return
  fi

  local health
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "unknown")
  echo "$health"
}

# ---------------------------------------------------------------------------
# Main wait loop
# ---------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}Waiting for stack '$STACK' to become healthy (timeout: ${TIMEOUT}s)${NC}"

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  containers=()
  while IFS= read -r c; do
    [[ -n "$c" ]] && containers+=("$c")
  done < <(get_stack_containers)

  if [[ ${#containers[@]} -eq 0 ]]; then
    log_warn "No containers found for stack '$STACK'. Are they running?"
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
    continue
  fi

  all_healthy=true
  status_line=""

  for c in "${containers[@]}"; do
    health=$(container_health "$c")
    case "$health" in
      healthy) status_line+=" ${GREEN}✓${NC}$c" ;;
      none)    status_line+=" ${GREEN}~${NC}$c" ;;  # No healthcheck defined
      starting) status_line+=" ${YELLOW}…${NC}$c"; all_healthy=false ;;
      exited)  status_line+=" ${RED}✗${NC}$c"; all_healthy=false ;;
      *)       status_line+=" ${YELLOW}?${NC}$c"; all_healthy=false ;;
    esac
  done

  echo -ne "\r  [${elapsed}s]${status_line}  "

  if [[ "$all_healthy" == "true" ]]; then
    echo ""
    echo ""
    log_info "${GREEN}${BOLD}✓ All ${#containers[@]} container(s) in '$STACK' are healthy!${NC}"
    exit 0
  fi

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

# ---------------------------------------------------------------------------
# Timeout — print diagnostics
# ---------------------------------------------------------------------------
echo ""
echo ""
log_error "Timeout after ${TIMEOUT}s. Not all containers are healthy."
echo ""

echo -e "${RED}${BOLD}=== Unhealthy Containers ===${NC}"
containers=()
while IFS= read -r c; do
  [[ -n "$c" ]] && containers+=("$c")
done < <(get_stack_containers)

for c in "${containers[@]}"; do
  health=$(container_health "$c")
  if [[ "$health" != "healthy" && "$health" != "none" ]]; then
    echo ""
    echo -e "${RED}--- $c (status: $health) ---${NC}"
    echo "Last 50 lines of logs:"
    docker logs --tail 50 "$c" 2>&1 | sed 's/^/  /'
  fi
done

exit 1
