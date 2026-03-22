#!/bin/bash
# wait-healthy.sh - 等待容器健康
# 用法: ./tests/lib/wait-healthy.sh --timeout 120 [--stack base]

set -o pipefail

TIMEOUT=120
STACK="base"

while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --stack)
            STACK="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "Waiting for $STACK stack containers to be healthy (timeout: ${TIMEOUT}s)..."

COMPOSE_FILE="stacks/$STACK/docker-compose.yml"
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    ALL_HEALTHY=true
    
    # 获取所有服务
    SERVICES=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null)
    
    for SERVICE in $SERVICES; do
        HEALTH=$(docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Health}}" 2>/dev/null | grep "$SERVICE" | awk '{print $2}')
        
        if [[ "$HEALTH" == "unhealthy" ]]; then
            ALL_HEALTHY=false
            echo "  $SERVICE: unhealthy"
        elif [[ "$HEALTH" == "healthy" || "$HEALTH" == "-" ]]; then
            echo "  $SERVICE: OK"
        else
            ALL_HEALTHY=false
            echo "  $SERVICE: $HEALTH"
        fi
    done
    
    if [[ "$ALL_HEALTHY" == true ]]; then
        echo "All containers are healthy!"
        exit 0
    fi
    
    sleep 5
    ((ELAPSED+=5))
    echo "Waiting... ($ELAPSED/${TIMEOUT}s)"
done

echo "Timeout waiting for containers to be healthy"
exit 1
