#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local expected_status="$3"

    local status=$(curl -o /dev/null -s -w "%{http_code}" "$url")
    local delay=$(curl -o /dev/null -s -w "%{time_total}" "$url")

    if [[ "$status" == "$expected_status" ]]; then
        echo "[OK]   $name ($url) — 延迟 $(echo "$delay" | awk '{printf "%.0fms\n", $1*1000}')"
    elif [[ "$status" -ne 0 ]]; then
        echo "[SLOW] $name ($url) — 延迟 $(echo "$delay" | awk '{printf "%.0fms\n", $1*1000}') ⚠️ 建议开启镜像加速"
    else
        echo "[FAIL] $name ($url) — 连接超时 ✗ 需要使用国内镜像"
    fi
}

check_connectivity "https://hub.docker.com" "Docker Hub" "200"
check_connectivity "https://github.com" "GitHub" "200"
check_connectivity "https://gcr.io" "gcr.io" "200"
check_connectivity "https://ghcr.io" "ghcr.io" "200"

if ! nslookup github.com > /dev/null 2>&1; then
    echo "[FAIL] DNS 解析正常 ✗"
else
    echo "[OK]   DNS 解析正常"
fi

for port in 443 80; do
    if ! nc -zv -w5 github.com $port 2>&1 | grep -q "succeeded"; then
        echo "[FAIL] $port 出站端口开放 ✗"
    else
        echo "[OK]   $port 出站端口开放"
    fi
done
