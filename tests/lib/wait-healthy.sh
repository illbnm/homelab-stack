#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Wait for Healthy Containers
# =============================================================================
# Waits until all containers in the specified compose file are healthy.
#
# Usage:
#   ./tests/lib/wait-healthy.sh [--timeout 120] [--compose <file>]
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
TIMEOUT=120
COMPOSE_FILE=""
INTERVAL=5

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --compose)
      COMPOSE_FILE="$2"
      shift 2
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--timeout <seconds>] [--compose <file>] [--interval <seconds>]"
      echo ""
      echo "Waits for all containers with healthchecks to become healthy."
      echo ""
      echo "Options:"
      echo "  --timeout   Maximum seconds to wait (default: 120)"
      echo "  --compose   Compose file to check (optional; checks all running containers if omitted)"
      echo "  --interval  Seconds between checks (default: 5)"
      exit 0
      ;;
    *)
      echo -e "${RED}[ERROR]${NC} Unknown option: $1"
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[WAIT]${NC} Waiting up to ${TIMEOUT}s for containers to become healthy..."

WAITED=0
while [[ "${WAITED}" -lt "${TIMEOUT}" ]]; do
  # Get all containers with health checks
  if [[ -n "${COMPOSE_FILE}" ]]; then
    CONTAINERS=$(docker compose -f "${COMPOSE_FILE}" ps -q 2>/dev/null || echo "")
  else
    CONTAINERS=$(docker ps -q 2>/dev/null || echo "")
  fi

  if [[ -z "${CONTAINERS}" ]]; then
    echo -e "${YELLOW}[WAIT]${NC} No containers found yet... (${WAITED}s)"
    sleep "${INTERVAL}"
    WAITED=$((WAITED + INTERVAL))
    continue
  fi

  ALL_HEALTHY=true
  NOT_READY=""

  for container_id in ${CONTAINERS}; do
    NAME=$(docker inspect --format='{{.Name}}' "${container_id}" 2>/dev/null | sed 's/^\///')
    HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "${container_id}" 2>/dev/null || echo "unknown")

    if [[ "${HEALTH}" == "healthy" || "${HEALTH}" == "no-healthcheck" ]]; then
      continue
    fi

    ALL_HEALTHY=false
    NOT_READY="${NOT_READY} ${NAME}(${HEALTH})"
  done

  if [[ "${ALL_HEALTHY}" == true ]]; then
    echo -e "${GREEN}[WAIT]${NC} All containers are healthy! (${WAITED}s)"
    exit 0
  fi

  echo -e "${YELLOW}[WAIT]${NC} Still waiting... (${WAITED}s) Not ready:${NOT_READY}"
  sleep "${INTERVAL}"
  WAITED=$((WAITED + INTERVAL))
done

echo -e "${RED}[WAIT]${NC} Timeout after ${TIMEOUT}s. Not all containers are healthy."

# Show final status
if [[ -n "${COMPOSE_FILE}" ]]; then
  docker compose -f "${COMPOSE_FILE}" ps 2>/dev/null || true
else
  docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
fi

exit 1
