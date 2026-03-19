#!/usr/bin/env bash
# check-connectivity.sh — 网络连通性检测

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$BASE_DIR/stacks/robustness/config/cn-mirrors.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}=== 网络连通性检测 ===${NC}"

# 读取配置
if [[ -f "$CONFIG" ]]; then
  urls=($(yq '.network.test_urls[]' "$CONFIG" 2>/dev/null || grep -oP 'https://\K[^"]+' "$CONFIG"))
else
  urls=(
    "https://docker.io"
    "https://hub.docker.com"
    "https://ghcr.io"
    "https://gcr.io"
    "https://quay.io"
  )
fi

timeout=10
retries=2

echo "测试目标: ${urls[*]}"
echo "超时: ${timeout}s, 重试: ${retries}"
echo

# 测试函数
test_url() {
  local url=$1
  echo -n "Testing $url... "

  for i in $(seq 1 $retries); do
    if curl -sI --connect-timeout $timeout "$url" &>/dev/null; then
      echo -e "${GREEN}✓${NC}"
      return 0
    fi
  done

  echo -e "${RED}✗${NC}"
  return 1
}

# 执行测试
failed=0
for url in "${urls[@]}"; do
  if ! test_url "$url"; then
    ((failed++))
  fi
done

echo
echo "=== 结果 ==="
if [[ $failed -eq 0 ]]; then
  echo -e "${GREEN}✅ 所有目标可达${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠️  $failed 个目标不可达${NC}"
  echo "建议:"
  echo "1. 检查 DNS 配置"
  echo "2. 检查防火墙规则"
  echo "3. 使用代理或镜像加速"
  exit 1
fi