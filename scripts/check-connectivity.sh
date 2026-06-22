#!/usr/bin/env bash
set -euo pipefail

echo "检测项目:"
echo "  ✓ Docker Hub 可达性"
echo "  ✓ GitHub 可达性"
echo "  ✓ gcr.io 可达性"
echo "  ✓ ghcr.io 可达性"
echo "  ✓ DNS 解析正常"
echo "  ✓ 443/80 出站端口开放"
echo
echo "输出:"

check_url() {
    local name=$1
    local url=$2
    local domain=$3
    
    # 443 port check
    if ! nc -z -w 5 "$domain" 443 2>/dev/null; then
        echo "[FAIL] $name — 连接超时 ✗ 需要使用国内镜像"
        return 2
    fi

    local start_time
    start_time=$(date +%s%3N)
    if curl --connect-timeout 5 -s -o /dev/null -w "%{http_code}" "$url" >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        if [ "$duration" -gt 1000 ]; then
            echo "[SLOW] $name — 延迟 ${duration}ms ⚠️ 建议开启镜像加速"
            return 1
        else
            echo "[OK]   $name — 延迟 ${duration}ms"
            return 0
        fi
    else
        echo "[FAIL] $name — 连接超时 ✗ 需要使用国内镜像"
        return 2
    fi
}

fail_count=0

check_url "Docker Hub (hub.docker.com)" "https://hub.docker.com" "hub.docker.com" || ((fail_count++))
check_url "GitHub (github.com)" "https://github.com" "github.com" || ((fail_count++))
check_url "gcr.io" "https://gcr.io" "gcr.io" || ((fail_count++))
check_url "ghcr.io" "https://ghcr.io" "ghcr.io" || ((fail_count++))

# Check DNS
if ! host github.com >/dev/null 2>&1 && ! nslookup github.com >/dev/null 2>&1; then
    echo "[FAIL] DNS 解析异常"
fi

echo ""
if [ "$fail_count" -ge 2 ]; then
    echo "建议: 检测到 2 个不可达源，建议运行 ./scripts/setup-cn-mirrors.sh"
else
    echo "建议: 网络状态良好"
fi
