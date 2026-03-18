#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# wait-healthy.sh — 等待所有容器达到 healthy 状态
#
# 用法: ./tests/lib/wait-healthy.sh [--timeout <seconds>]
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

TIMEOUT=${1:-120}
shift || true

echo "Waiting for all containers to be healthy (timeout: ${TIMEOUT}s)..."

start=$(date +%s)
failed_containers=()

while true; do
  # 获取所有运行中的容器
  containers=$(docker ps --filter "status=running" --format '{{.Names}}' 2>/dev/null || true)

  if [[ -z "$containers" ]]; then
    echo "No running containers found"
    exit 1
  fi

  all_healthy=true
  for container in $containers; do
    # 检查是否有 healthcheck
    if docker inspect --format='{{.Config.Healthcheck.Test}}' "$container" 2>/dev/null | grep -q .; then
      status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
      if [[ "$status" != "healthy" ]]; then
        echo "  ❌ $container: $status (not healthy yet)"
        all_healthy=false
        # 记录不健康的容器
        if [[ ! " ${failed_containers[*]} " =~ " $container " ]]; then
          failed_containers+=("$container")
        fi
      else
        echo "  ✅ $container: healthy"
      fi
    else
      # 没有 healthcheck 的容器，只检查运行状态
      echo "  ⏭️  $container: no healthcheck, skipping"
    fi
  done

  if $all_healthy; then
    echo "✅ All containers with healthcheck are healthy!"
    exit 0
  fi

  elapsed=$(( $(date +%s) - start ))
  if [[ $elapsed -ge $TIMEOUT ]]; then
    echo "⏰ Timeout after ${TIMEOUT}s"
    echo "Failed containers: ${failed_containers[*]}"
    echo "Check logs:"
    for c in "${failed_containers[@]}"; do
      echo "  docker logs $c --tail 50"
    done
    exit 1
  fi

  sleep 5
done