#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10

    if curl --connect-timeout "$timeout" --max-time "$timeout" -s -o /dev/null -w "%{http_code}" "$url" &> /dev/null; then
        echo "[OK]   $name ($url)"
    else
        echo "[FAIL] $name ($url) — 连接超时 ✗"
    fi
}

echo "Checking connectivity..."
check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

if nslookup google.com &> /dev/null; then
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