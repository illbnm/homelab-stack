#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local timeout=10
    local result=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout $timeout "$url")
    if [[ "$result" -eq 200 ]]; then
        echo "[OK]   $name ($url)"
    else
        echo "[FAIL] $name ($url) — HTTP $result"
    fi
}

echo "Checking connectivity..."
check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"
check_connectivity "https://gcr.io" "gcr.io"
check_connectivity "https://ghcr.io" "ghcr.io"

echo "Checking DNS resolution..."
if nslookup google.com > /dev/null 2>&1; then
    echo "[OK]   DNS resolution"
else
    echo "[FAIL] DNS resolution"
fi

echo "Checking outbound ports..."
for port in 80 443; do
    if nc -zv -w5 google.com $port 2>&1 | grep -q succeeded; then
        echo "[OK]   Port $port"
    else
        echo "[FAIL] Port $port"
    fi
done