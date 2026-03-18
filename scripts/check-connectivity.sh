#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — 网络连通性检测
# =============================================================================

set -euo pipefail

TIMEOUT=5
PASS=0
FAIL=0
SLOW=0

check() {
  local name="$1" url="$2"
  local start=$(date +%s%N)
  if curl -sf --connect-timeout "$TIMEOUT" --max-time 10 -o /dev/null "$url" 2>/dev/null; then
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    if [[ $ms -gt 1000 ]]; then
      echo "  [SLOW] ${name} (${url}) — ${ms}ms ⚠️ 建议开启镜像加速"
      ((SLOW++))
    else
      echo "  [OK]   ${name} (${url}) — ${ms}ms"
    fi
    ((PASS++))
  else
    echo "  [FAIL] ${name} (${url}) — 连接超时 ✗ 需要使用国内镜像"
    ((FAIL++))
  fi
}

echo ""
echo "=============================================="
echo "  网络连通性检测"
echo "=============================================="
echo ""

check "Docker Hub"    "https://hub.docker.com"
check "GitHub"        "https://github.com"
check "gcr.io"        "https://gcr.io"
check "ghcr.io"       "https://ghcr.io"
check "quay.io"       "https://quay.io"
check "DNS (Google)"  "https://dns.google"
check "DNS (CF)"      "https://1.1.1.1"

echo ""
echo "=============================================="
echo "  结果: ${PASS} 通过, ${SLOW} 慢, ${FAIL} 失败"
echo "=============================================="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "  建议: 检测到 ${FAIL} 个不可达源"
  echo "  运行 sudo ./scripts/setup-cn-mirrors.sh 配置镜像加速"
  echo "  运行 ./scripts/localize-images.sh --cn 替换为国内镜像"
fi
