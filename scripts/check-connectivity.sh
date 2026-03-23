#!/bin/bash

check_connectivity() {
    local url=$1
    local name=$2
    local timeout=10
    local result=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout $timeout "$url" 2>/dev/null)

    if [[ -z "$result" ]]; then
        echo "[FAIL] $name ($url) — 连接超时 ✗"
    elif (( $(echo "$result > 1" | bc -l) )); then
        echo "[SLOW] $name ($url) — 延迟 $(printf "%.0f" $(echo "$result * 1000" | bc))ms ⚠️"
    else
        echo "[OK]   $name ($url) — 延迟 $(printf "%.0f" $(echo "$result * 1000" | bc))ms"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

if nslookup github.com > /dev/null 2>&1; then
    echo "[OK]   DNS 解析正常"
else
    echo "[FAIL] DNS 解析失败 ✗"
fi

if nc -zv 8.8.8.8 443 2>/dev/null; then
    echo "[OK]   443 出站端口开放"
else
    echo "[FAIL] 443 出站端口未开放 ✗"
fi

if nc -zv 8.8.8.8 80 2>/dev/null; then
    echo "[OK]   80 出站端口开放"
else
    echo "[FAIL] 80 出站端口未开放 ✗"
fi