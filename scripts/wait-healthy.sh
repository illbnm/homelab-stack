#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — Wait for all containers in a stack to become healthy
# Usage: ./wait-healthy.sh --stack <name> [--timeout 300]
# Exit codes: 0=healthy, 1=timeout, 2=container exited
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

STACK=""
TIMEOUT=300
for arg in "$@"; do
    case "$arg" in
        --stack) shift; STACK="${1:-}" ;;
        --timeout) shift; TIMEOUT="${1:-300}" ;;
    esac
done

if [[ -z "$STACK" ]]; then
    echo "Usage: $0 --stack <name> [--timeout 300]"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/stacks/$STACK/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "Compose file not found: $COMPOSE_FILE"
    exit 2
fi

echo "Waiting for stack '$STACK' to be healthy (timeout: ${TIMEOUT}s)..."
ELAPSED=0
INTERVAL=5

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    # Check for exited containers
    EXITED=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}|{{.Status}}' 2>/dev/null | grep -E '\|.*Exit' || true)
    if [[ -n "$EXITED" ]]; then
        echo -e "${RED}Container exited:${NC}"
        echo "$EXITED" | while IFS='|' read -r name status; do
            echo "  $name: $status"
            docker logs --tail 50 "$name" 2>/dev/null
        done
        exit 2
    fi

    # Check all containers healthy
    UNHEALTHY=0
    TOTAL=0
    while IFS='|' read -r name status; do
        [[ -z "$name" ]] && continue
        TOTAL=$((TOTAL + 1))
        if ! echo "$status" | grep -qiE 'healthy|running'; then
            UNHEALTHY=$((UNHEALTHY + 1))
        fi
    done < <(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}|{{.Status}}' 2>/dev/null)

    if [[ $UNHEALTHY -eq 0 && $TOTAL -gt 0 ]]; then
        echo -e "${GREEN}All $TOTAL containers healthy!${NC}"
        exit 0
    fi

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    echo "  ... ${ELAPSED}s elapsed ($UNHEALTHY/$TOTAL unhealthy)"
done

echo -e "${YELLOW}Timeout after ${TIMEOUT}s. Unhealthy containers:${NC}"
docker compose -f "$COMPOSE_FILE" ps 2>/dev/null
exit 1
