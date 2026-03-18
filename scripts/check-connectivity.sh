#!/bin/bash

check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10

    echo -n "Checking $name ($url)..."
    response=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout "$timeout" "$url" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo " [FAIL] $name ($url) — 连接超时 ✗"
    elif (( $(echo "$response > 1" | bc -l) )); then
        echo " [SLOW] $name ($url) — 延迟 ${response}s ⚠️"
    else
        echo " [OK]   $name ($url) — 延迟 ${response}s"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

echo -n "Checking DNS resolution..."
if nslookup github.com > /dev/null 2>&1; then
    echo " [OK]"
else
    echo " [FAIL]"
fi

echo -n "Checking port 443..."
if nc -zv github.com 443 > /dev/null 2>&1; then
    echo " [OK]"
else
    echo " [FAIL]"
fi

echo -n "Checking port 80..."
if nc -zv github.com 80 > /dev/null 2>&1; then
    echo " [OK]"
else
    echo " [FAIL]"
fi