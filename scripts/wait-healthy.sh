#!/usr/bin/env bash
# =============================================================================
# Wait for Healthy — 等待所有容器健康
# Polls container health checks until all pass or timeout.
# Usage: ./scripts/wait-healthy.sh --stack <name> [--timeout 300]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ─── Parse Arguments ────────────────────────────────────────────────────────
STACK=""
TIMEOUT=300
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)    STACK="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --stack <name> [--timeout <seconds>] [--interval <seconds>]"
      echo ""
      echo "Options:"
      echo "  --stack     Stack name (e.g., base, monitoring, sso)"
      echo "  --timeout   Max wait time in seconds (default: 300)"
      echo "  --interval  Poll interval in seconds (default: 5)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$STACK" ]]; then
  echo "Error: --stack is required"
  echo "Usage: $0 --stack <name> [--timeout 300]"
  exit 2
fi

STACK_DIR="$ROOT_DIR/stacks/$STACK"
if [[ ! -f "$STACK_DIR/docker-compose.yml" ]]; then
  log_error "Stack not found: $STACK_DIR/docker-compose.yml"
  exit 2
fi

# ─── Wait Loop ──────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Waiting for stack '$STACK' to be healthy"
echo "  Timeout: ${TIMEOUT}s | Interval: ${INTERVAL}s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  # Get container states
  all_healthy=true
  unhealthy_containers=()
  exited_containers=()

  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    health=$(echo "$line" | awk '{print $3}')

    if [[ "$state" == "exited" || "$state" == "dead" ]]; then
      exited_containers+=("$name")
      all_healthy=false
    elif [[ "$health" != "healthy" && "$health" != "" && "$health" != "(healthy)" ]]; then
      # Container is running but not yet healthy
      unhealthy_containers+=("$name")
      all_healthy=false
    fi
  done < <(cd "$STACK_DIR" && docker compose ps --format '{{.Name}} {{.State}} {{.Health}}' 2>/dev/null || true)

  # Check for exited containers (fatal)
  if [[ ${#exited_containers[@]} -gt 0 ]]; then
    echo ""
    log_error "Containers have exited:"
    for c in "${exited_containers[@]}"; do
      echo -e "  ${RED}✗${NC} $c"
      echo "  Last 50 lines:"
      docker logs --tail 50 "$c" 2>&1 | sed 's/^/    /'
      echo ""
    done
    exit 2
  fi

  if $all_healthy; then
    echo ""
    log_info "All containers in stack '$STACK' are healthy! (${elapsed}s)"
    # Print final status
    cd "$STACK_DIR" && docker compose ps
    exit 0
  fi

  # Progress output
  printf "\r  [%3ds/%ds] Waiting... %d unhealthy: %s" \
    "$elapsed" "$TIMEOUT" \
    "${#unhealthy_containers[@]}" \
    "$(IFS=', '; echo "${unhealthy_containers[*]:-none}")"

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

# ─── Timeout ────────────────────────────────────────────────────────────────
echo ""
log_error "Timeout after ${TIMEOUT}s — not all containers are healthy"
echo ""

# Print status of all containers
echo "Container Status:"
cd "$STACK_DIR" && docker compose ps
echo ""

# Print logs for unhealthy containers
if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
  echo "Logs for unhealthy containers:"
  for c in "${unhealthy_containers[@]}"; do
    echo ""
    echo -e "  ${YELLOW}─── $c ───${NC}"
    docker logs --tail 50 "$c" 2>&1 | sed 's/^/    /'
  done
fi

exit 1
