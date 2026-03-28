#!/usr/bin/env bash
# =============================================================================
# Wait for container(s) to be healthy
# Usage: wait-healthy.sh --container <name> [--container <name2>] [--timeout <secs>]
# =============================================================================

set -euo pipefail

TIMEOUT=120
CONTAINERS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container)
            CONTAINERS+=("$2")
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --container <name> [--container <name2>] [--timeout <secs>]"
            echo "Waits for container(s) to be healthy (or running without healthcheck)."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
    echo "Error: No containers specified"
    exit 1
fi

wait_for_container() {
    local name="$1"
    local elapsed=0
    local interval=2

    echo -n "Waiting for $name to be healthy... "

    while [[ $elapsed -lt $TIMEOUT ]]; do
        local status health
        status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "missing")
        health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck")

        if [[ "$status" == "running" ]]; then
            if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
                echo "✓ (${elapsed}s)"
                return 0
            fi
        elif [[ "$status" == "missing" ]]; then
            echo "✗ container not found"
            return 1
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "✗ timeout after ${TIMEOUT}s (status: $status, health: $health)"
    return 1
}

all_ok=true
for container in "${CONTAINERS[@]}"; do
    if ! wait_for_container "$container"; then
        all_ok=false
    fi
done

if $all_ok; then
    echo "All containers are healthy."
    exit 0
else
    echo "Some containers failed to become healthy."
    exit 1
fi
