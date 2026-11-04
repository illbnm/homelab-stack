#!/usr/bin/env bash
# scripts/wait-healthy.sh
# Polls docker container health with automated diagnosis on timeout

set -euo pipefail

TIMEOUT=300
STACK_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack) STACK_NAME="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "[*] Waiting for containers to become healthy (timeout: ${TIMEOUT}s)..."
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "[!] Timeout reached! Fetching un-healthy container logs..."
        docker ps --filter "health=unhealthy" --format "{{.Names}}" | while read -r c; do
            echo "--- Logs for $c ---"
            docker logs --tail 50 "$c"
        done
        exit 1
    fi
    
    UNHEALTHY=$(docker ps --filter "health=starting" --filter "health=unhealthy" -q | wc -l)
    if [ "$UNHEALTHY" -eq 0 ]; then
        echo "[✓] All containers healthy!"
        exit 0
    fi
    sleep 5
done
