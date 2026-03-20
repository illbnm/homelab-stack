#!/bin/bash

check_connectivity() {
    local url=$1
    local name=$2
    local timeout=10

    echo -n "Checking $name ($url)..."
    response=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout $timeout "$url" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo " [FAIL] Connection timeout ✗"
    elif (( $(echo "$response > 1" | bc -l) )); then
        echo " [SLOW] Delay ${response}s ⚠️"
    else
        echo " [OK] Delay ${response}s"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

echo "Checking DNS resolution..."
if nslookup github.com > /dev/null 2>&1; then
    echo " [OK] DNS resolution"
else
    echo " [FAIL] DNS resolution"
fi

echo "Checking outbound ports 443 and 80..."
if nc -zv -w5 google.com 443 > /dev/null 2>&1; then
    echo " [OK] Port 443"
else
    echo " [FAIL] Port 443"
fi

if nc -zv -w5 google.com 80 > /dev/null 2>&1; then
    echo " [OK] Port 80"
else
    echo " [FAIL] Port 80"
fi