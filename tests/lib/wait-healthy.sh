#!/usr/bin/env bash
# 等待所有容器健康的辅助脚本

set -euo pipefail

TIMEOUT="${1:-120}"

echo "等待所有容器健康 (超时: ${TIMEOUT}s)..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    unhealthy=$(docker ps --filter "health=unhealthy" -q | wc -l)
    starting=$(docker ps --filter "health=starting" -q | wc -l)

    if [[ "$unhealthy" -eq 0 ]] && [[ "$starting" -eq 0 ]]; then
        echo "✅ 所有容器健康!"
        exit 0
    fi

    sleep 2
    ((elapsed += 2))
done

echo "❌ 等待超时"
docker ps --filter "health=unhealthy" --filter "health=starting"
exit 1
