#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10
    local delay=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout "$timeout" "$url" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        if (( $(echo "$delay < 1" | bc -l) )); then
            echo "[OK]   $name ($url) — 延迟 $(printf "%.0f" $(echo "$delay * 1000" | bc))ms"
        elif (( $(echo "$delay < 5" | bc -l) )); then
            echo "[SLOW] $name ($url) — 延迟 $(printf "%.0f" $(echo "$delay * 1000" | bc))ms ⚠️ 建议开启镜像加速"
        else
            echo "[FAIL] $name ($url) — 延迟 $(printf "%.0f" $(echo "$delay * 1000" | bc))ms ✗ 需要使用国内镜像"
        fi
    else
        echo "[FAIL] $name ($url) — 连接超时 ✗"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

if nslookup google.com &> /dev/null; then
    echo "[OK]   DNS 解析正常"
else
    echo "[FAIL] DNS 解析异常 ✗"
fi

for port in 443 80; do
    if nc -zv -w5 google.com "$port" &> /dev/null; then
        echo "[OK]   出站端口 $port 开放"
    else
        echo "[FAIL] 出站端口 $port 未开放 ✗"
    fi
done