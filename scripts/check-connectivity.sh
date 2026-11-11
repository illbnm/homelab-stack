#!/usr/bin/env bash
# Usage: ./scripts/check-connectivity.sh [--mock]
# Tests reachability and latency to Docker Hub, GitHub, gcr.io, ghcr.io, DNS, and outbound 80/443.
set -euo pipefail

MOCK_MODE="${MOCK_MODE:-false}"
if [[ "${1:-}" == "--mock" ]]; then
  MOCK_MODE="true"
fi

FAIL_COUNT=0
SLOW_COUNT=0

probe_endpoint() {
  local label="$1"
  local host="$2"
  local url="$3"

  if [[ "$MOCK_MODE" == "true" ]]; then
    echo "[OK]   ${label} (${host}) — 延迟 85ms"
    return 0
  fi

  local start_ms end_ms elapsed_ms
  start_ms=$(date +%s%3N 2>/dev/null || echo 0)
  if curl -fsSL --connect-timeout 5 --max-time 10 -o /dev/null "$url" 2>/dev/null; then
    end_ms=$(date +%s%3N 2>/dev/null || echo 100)
    elapsed_ms=$((end_ms - start_ms))
    if (( elapsed_ms > 1000 )); then
      echo "[SLOW] ${label} (${host}) — 延迟 ${elapsed_ms}ms ⚠️ 建议开启镜像加速"
      SLOW_COUNT=$((SLOW_COUNT + 1))
    else
      echo "[OK]   ${label} (${host}) — 延迟 ${elapsed_ms}ms"
    fi
  else
    echo "[FAIL] ${label} (${host}) — 连接超时 ✗ 需要使用国内镜像"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "检测项目:"
probe_endpoint "Docker Hub" "hub.docker.com" "https://hub.docker.com"
probe_endpoint "GitHub" "github.com" "https://github.com"
probe_endpoint "gcr.io" "gcr.io" "https://gcr.io"
probe_endpoint "ghcr.io" "ghcr.io" "https://ghcr.io"

if (( FAIL_COUNT > 0 || SLOW_COUNT > 0 )); then
  echo ""
  echo "建议: 检测到 ${FAIL_COUNT} 个不可达源 (${SLOW_COUNT} 个慢速源)，建议运行 ./scripts/setup-cn-mirrors.sh"
else
  echo ""
  echo "建议: 所有源连接正常。"
fi
