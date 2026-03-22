#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10
    local result=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout "$timeout" "$url" 2>/dev/null)

    if [[ -z "$result" ]]; then
        echo "[FAIL] $name ($url) — 连接超时 ✗"
    elif (( $(echo "$result > 1" | bc -l) )); then
        echo "[SLOW] $name ($url) — 延迟 $(printf "%.0fms" "$(echo "$result * 1000" | bc)") ⚠️"
    else
        echo "[OK]   $name ($url) — 延迟 $(printf "%.0fms" "$(echo "$result * 1000" | bc)")"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

if nslookup google.com > /dev/null 2>&1; then
    echo "[OK]   DNS 解析正常"
else
    echo "[FAIL] DNS 解析失败 ✗"
fi

for port in 443 80; do
    if nc -zv -w5 google.com "$port" &> /dev/null; then
        echo "[OK]   出站端口 $port 开放"
    else
        echo "[FAIL] 出站端口 $port 未开放 ✗"
    fi
done

exit 0