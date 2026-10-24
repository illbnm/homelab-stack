#!/usr/bin/env bash
# Polling wait for container health
set -e

TIMEOUT=300
STACK="all"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --stack) STACK="$2"; shift ;;
        --timeout) TIMEOUT="$2"; shift ;;
    esac
    shift
done

echo "Waiting for stack '$STACK' containers to be healthy (timeout: ${TIMEOUT}s)..."
START_TIME=$(date +%s)

while true; do
    UNHEALTHY=$(docker ps -q --filter health=unhealthy)
    STARTING=$(docker ps -q --filter health=starting)
    
    if [ -z "$UNHEALTHY" ] && [ -z "$STARTING" ]; then
        echo "[OK] All containers healthy!"
        exit 0
    fi

    NOW=$(date +%s)
    if [ $((NOW - START_TIME)) -ge "$TIMEOUT" ]; then
        echo "[ERROR] Timeout waiting for healthy containers!"
        for cid in $UNHEALTHY $STARTING; do
            echo "--- Logs for container $cid (last 50 lines) ---"
            docker logs --tail 50 "$cid"
        done
        exit 1
    fi
    sleep 5
done
