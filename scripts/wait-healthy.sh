#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Wait for Container Health
# Usage: wait-healthy.sh --stack <name> [--timeout 300]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

STACK=""
TIMEOUT=300
INTERVAL=5
CONTAINERS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$STACK" ]; then
  echo "Usage: wait-healthy.sh --stack <name> [--timeout 300]"
  exit 1
fi

# Get containers for this stack
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=${STACK}" --format '{{.Names}}' 2>/dev/null || echo "")
if [ -z "$CONTAINERS" ]; then
  # Try alternate label format
  CONTAINERS=$(docker ps --format '{{.Names}}' | grep -i "$STACK" || echo "")
fi

if [ -z "$CONTAINERS" ]; then
  log_error "No containers found for stack: $STACK"
  exit 2
fi

echo -e "${CYAN}Waiting for $STACK containers to become healthy...${RESET}"
echo "Timeout: ${TIMEOUT}s | Interval: ${INTERVAL}s"
echo ""

ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  ALL_HEALTHY=true
  
  for container in $CONTAINERS; do
    local status
    status=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
    
    case "$status" in
      healthy)
        echo -e "  ${GREEN}✓${RESET} $container (healthy)"
        ;;
      starting)
        echo -e "  ${YELLOW}⏳${RESET} $container (starting...)"
        ALL_HEALTHY=false
        ;;
      unhealthy)
        echo -e "  ${RED}✗${RESET} $container (unhealthy)"
        ALL_HEALTHY=false
        ;;
      *)
        echo -e "  ${YELLOW}?${RESET} $container ($status)"
        ALL_HEALTHY=false
        ;;
    esac
  done
  
  if $ALL_HEALTHY; then
    echo ""
    log_info "All containers healthy!"
    exit 0
  fi
  
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
  echo ""
done

# Timeout — print logs of unhealthy containers
echo ""
log_error "Timeout after ${TIMEOUT}s. Unhealthy container logs:"
for container in $CONTAINERS; do
  status=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
  if [ "$status" != "healthy" ]; then
    echo ""
    echo "── $container ($status) ──"
    docker logs --tail 50 "$container" 2>/dev/null || echo "  (no logs available)"
  fi
done

exit 1
