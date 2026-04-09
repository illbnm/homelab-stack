#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Wait for Healthy Containers
# Polls container health until all are healthy or timeout.
#
# Usage: ./scripts/wait-healthy.sh --stack <name> [--timeout 300] [--quiet]
# Exit: 0=all healthy, 1=timeout, 2=container exited
# =============================================================================
set -euo pipefail

STACK=""
TIMEOUT=300
QUIET=false

while [ $# -gt 0 ]; do
  case "$1" in
    --stack)   STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --quiet)   QUIET=true; shift ;;
    --help)    echo "Usage: $0 --stack <name> [--timeout 300] [--quiet]"; exit 0 ;;
    *)         echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$STACK" ]; then
  echo "Error: --stack is required"
  echo "Usage: $0 --stack <name> [--timeout 300]"
  exit 1
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

elapsed=0
interval=5

# Find the compose file for this stack
COMPOSE_FILE=""
for search in \
  "stacks/${STACK}/docker-compose.yml" \
  "stacks/${STACK}/docker-compose.yaml" \
  "${STACK}/docker-compose.yml" \
  "${STACK}/docker-compose.yaml"; do
  if [ -f "$search" ]; then
    COMPOSE_FILE="$search"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo -e "${RED}[ERROR]${NC} Cannot find docker-compose.yml for stack '$STACK'"
  exit 2
fi

while [ "$elapsed" -lt "$TIMEOUT" ]; do
  # Get all services defined in the compose file
  services=$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null) || {
    echo -e "${RED}[ERROR]${NC} Failed to parse $COMPOSE_FILE"
    exit 2
  }

  all_healthy=true
  unhealthy_list=""
  exited_list=""

  for svc in $services; do
    # Get container name (use service name as label)
    container=$(docker compose -f "$COMPOSE_FILE" ps -q "$svc" 2>/dev/null | head -1) || true

    if [ -z "$container" ]; then
      all_healthy=false
      unhealthy_list="$unhealthy_list $svc(not-created)"
      continue
    fi

    state=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null) || state="unknown"
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null) || health="none"

    if [ "$state" = "exited" ] || [ "$state" = "dead" ]; then
      exited_list="$exited_list $svc($state)"
      continue
    fi

    if [ "$health" = "none" ]; then
      # Container has no healthcheck, consider running as healthy
      if [ "$state" = "running" ]; then
        if ! $QUIET; then
          echo -e "  ${GREEN}[OK]${NC} $svc — running (no healthcheck)"
        fi
        continue
      fi
    fi

    if [ "$health" != "healthy" ]; then
      all_healthy=false
      unhealthy_list="$unhealthy_list $svc($health/$state)"
    fi
  done

  # Check for exited containers
  if [ -n "$exited_list" ]; then
    echo -e "${RED}[EXIT]${NC} Containers exited: $exited_list"
    for svc in $exited_list; do
      svc_name="${svc%%(*}"
      echo -e "${YELLOW}[LOGS]${NC} Last 50 lines of $svc_name:"
      docker compose -f "$COMPOSE_FILE" logs --tail 50 "$svc_name" 2>/dev/null || true
    done
    exit 2
  fi

  if $all_healthy; then
    if ! $QUIET; then
      echo -e "${GREEN}[OK]${NC} All containers in stack '$STACK' are healthy (${elapsed}s)"
    fi
    exit 0
  fi

  if ! $QUIET; then
    echo -e "${YELLOW}[WAIT]${NC} ${elapsed}/${TIMEOUT}s — unhealthy:$unhealthy_list"
  fi
  sleep "$interval"
  elapsed=$((elapsed + interval))
done

# Timeout
echo -e "${RED}[TIMEOUT]${NC} Stack '$STACK' did not become healthy in ${TIMEOUT}s"
echo

# Show logs for unhealthy containers
for svc in $unhealthy_list; do
  svc_name="${svc%%(*}"
  echo -e "${YELLOW}[LOGS]${NC} Last 50 lines of $svc_name:"
  docker compose -f "$COMPOSE_FILE" logs --tail 50 "$svc_name" 2>/dev/null || true
  echo
done

exit 1
