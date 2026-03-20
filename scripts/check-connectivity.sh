#!/bin/bash

function check_connectivity() {
    local url="$1"
    local name="$2"
    local expected_status="${3:-200}"

    local status
    status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 10 "$url")

    if [[ "$status" -eq "$expected_status" ]]; then
        echo "[OK]   $name ($url) — 延迟 $(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 10 "$url")s"
    elif [[ "$status" -ne 0 ]]; then
        echo "[SLOW] $name ($url) — 延迟 $(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 10 "$url")s ⚠️ 建议开启镜像加速"
    else
        echo "[FAIL] $name ($url) — 连接超时 ✗ 需要使用国内镜像"
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

if nc -zv -w5 google.com 443 > /dev/null 2>&1; then
    echo "[OK]   443 出站端口开放"
else
    echo "[FAIL] 443 出站端口未开放 ✗"
fi

if nc -zv -w5 google.com 80 > /dev/null 2>&1; then
    echo "[OK]   80 出站端口开放"
else
    echo "[FAIL] 80 出站端口未开放 ✗"
fi

exit 0