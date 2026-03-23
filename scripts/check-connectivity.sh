#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10
    local result=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout "$timeout" "$url")
    if [[ "$result" -eq 200 ]]; then
        local latency=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout "$timeout" "$url")
        latency=$(echo "$latency * 1000" | bc)
        echo "[OK]   $name ($url) — 延迟 ${latency}ms"
    else
        echo "[FAIL] $name ($url) — 连接超时 ✗"
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

if nc -zv google.com 443 > /dev/null 2>&1; then
    echo "[OK]   443 出站端口开放"
else
    echo "[FAIL] 443 出站端口未开放 ✗"
fi

if nc -zv google.com 80 > /dev/null 2>&1; then
    echo "[OK]   80 出站端口开放"
else
    echo "[FAIL] 80 出站端口未开放 ✗"
fi

exit 0