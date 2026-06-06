#!/bin/bash
# wait-healthy.sh - Wait for docker compose stack containers to be healthy
# Usage: ./wait-healthy.sh --stack <name> [--timeout <seconds>]
#
# Exits 0 when all containers in the stack are in "running" state.
# Exits 1 if timeout is reached before all containers are healthy.
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

STACK=""
TIMEOUT=300
POLL_INTERVAL=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack) STACK="$2"; shift 2;;
        --timeout) TIMEOUT="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

if [[ -z "$STACK" ]]; then
    echo "Usage: $0 --stack <stack-name> [--timeout <seconds>]"
    echo ""
    echo "Example:"
    echo "  $0 --stack myapp --timeout 600"
    exit 1
fi

info "Waiting for stack '$STACK' to be healthy (timeout: ${TIMEOUT}s)..."

START=$(date +%s)
ELAPSED=0

while true; do
    ELAPSED=$(($(date +%s) - START))

    if [[ $ELAPSED -gt $TIMEOUT ]]; then
        error "Timeout reached (${TIMEOUT}s)"
        info "Current container status:"
        docker compose -p "$STACK" ps 2>/dev/null || docker-compose -p "$STACK" ps 2>/dev/null
        exit 1
    fi

    # Get all container states
    local all_running=true
    local container_count=0
    local running_count=0

    # Try docker compose first, then docker-compose
    local ps_output
    ps_output=$(docker compose -p "$STACK" ps --format json 2>/dev/null) ||     ps_output=$(docker-compose -p "$STACK" ps --format json 2>/dev/null) || true

    if [[ -n "$ps_output" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local state
            state=$(echo "$line" | jq -r '.State // .Status // "unknown"' 2>/dev/null || echo "unknown")
            ((container_count++)) || true
            if [[ "$state" == "running" ]] || [[ "$state" == "healthy" ]]; then
                ((running_count++)) || true
            else
                all_running=false
            fi
        done <<< "$ps_output"
    else
        # Fallback: parse text output
        local lines
        lines=$(docker compose -p "$STACK" ps 2>/dev/null | tail -n +2) ||                 lines=$(docker-compose -p "$STACK" ps 2>/dev/null | tail -n +2) || true
        if [[ -n "$lines" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                ((container_count++)) || true
                if echo "$line" | grep -qE "Up|running|healthy"; then
                    ((running_count++)) || true
                else
                    all_running=false
                fi
            done <<< "$lines"
        else
            warn "Could not get container status for stack '$STACK'"
            all_running=false
        fi
    fi

    if $all_running && [[ $container_count -gt 0 ]]; then
        ok "All $container_count container(s) are healthy!"
        exit 0
    fi

    info "  ${ELAPSED}s elapsed... ${running_count:-0}/${container_count:-0} containers running"
    sleep $POLL_INTERVAL
done
