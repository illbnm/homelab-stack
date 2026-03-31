#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试地址
declare -A TESTS=(
  ["Docker Hub"]="hub.docker.com:443"
  ["GitHub"]="github.com:443"
  ["gcr.io"]="gcr.io:443"
  ["ghcr.io"]="ghcr.io:443"
  ["Docker Registry"]="registry-1.docker.io:443"
)

# DNS 测试地址
DNS_TESTS=(
  "8.8.8.8"
  "1.1.1.1"
  "223.5.5.5"
)

# 端口测试
PORTS=(53 80 443 3000 8080)

echo "================================================"
echo "网络连通性检测"
echo "================================================"
echo ""

# 检测 DNS
echo "检测 DNS 解析..."
echo ""
local_dns=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -1 | awk '{print $2}')

if ping -c 1 -W 2 "$local_dns" > /dev/null 2>&1; then
  echo -e "${GREEN}[OK]${NC}   本地 DNS ($local_dns) 正常"
else
  echo -e "${RED}[FAIL]${NC} 本地 DNS ($local_dns) 无法访问"
fi

echo ""
echo "检测公网 DNS..."
for dns in "${DNS_TESTS[@]}"; do
  if ping -c 1 -W 2 "$dns" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC}   DNS $dns 可达"
    break
  fi
done

echo ""
echo "检测镜像源连通性..."
echo ""

failed_count=0
slow_count=0

for service in "${!TESTS[@]}"; do
  host_port="${TESTS[$service]}"
  host="${host_port%:*}"
  port="${host_port##*:}"
  
  start_time=$(date +%s%N)
  
  if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
    end_time=$(date +%s%N)
    latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $latency -gt 1000 ]]; then
      echo -e "${YELLOW}[SLOW]${NC} $service ($host:$port) — 延迟 ${latency}ms ⚠️  建议开启镜像加速"
      ((slow_count++))
    else
      echo -e "${GREEN}[OK]${NC}   $service ($host:$port) — 延迟 ${latency}ms"
    fi
  else
    echo -e "${RED}[FAIL]${NC} $service — 连接超时 ✗ 需要使用国内镜像"
    ((failed_count++))
  fi
done

echo ""
echo "检测出站端口..."
echo ""

for port in "${PORTS[@]}"; do
  if timeout 2 bash -c "echo > /dev/tcp/8.8.8.8/$port" 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   端口 $port 开放"
  else
    echo -e "${YELLOW}[WARN]${NC} 端口 $port 可能被限制"
  fi
done

echo ""
echo "================================================"
echo "检测结果汇总"
echo "================================================"

if [[ $failed_count -eq 0 && $slow_count -eq 0 ]]; then
  echo -e "${GREEN}✓ 网络环境正常，无需额外配置${NC}"
  exit 0
elif [[ $failed_count -gt 0 ]]; then
  echo -e "${YELLOW}检测到 $failed_count 个不可达源，建议运行:${NC}"
  echo "  sudo ./scripts/setup-cn-mirrors.sh"
  exit 1
else
  echo -e "${YELLOW}检测到 $slow_count 个高延迟源，可考虑启用镜像加速${NC}"
  exit 0
fi
