#!/bin/bash

function check_connectivity() {
  local url="$1"
  local name="$2"
  local timeout=10

  echo -n "Checking $name ($url)..."
  latency=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout $timeout "$url" 2>/dev/null)

  if [[ -z "$latency" ]]; then
    echo " [FAIL] $name ($url) — 连接超时 ✗"
    return 1
  fi

  latency=$(echo "$latency" | awk '{printf "%.0f\n", $1 * 1000}')
  if (( latency > 1000 )); then
    echo " [SLOW] $name ($url) — 延迟 $latency ms ⚠️ 建议开启镜像加速"
  else
    echo " [OK]   $name ($url) — 延迟 $latency ms"
  fi
  return 0
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

echo -n "Checking DNS resolution..."
if nslookup github.com &> /dev/null; then
  echo " [OK]"
else
  echo " [FAIL]"
fi

echo -n "Checking port 443..."
if nc -zv github.com 443 &> /dev/null; then
  echo " [OK]"
else
  echo " [FAIL]"
fi

echo -n "Checking port 80..."
if nc -zv github.com 80 &> /dev/null; then
  echo " [OK]"
else
  echo " [FAIL]"
fi