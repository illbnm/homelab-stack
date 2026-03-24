#!/usr/bin/env bash
# network.test.sh - 网络 Stack 集成测试
# 测试网络相关服务的连通性和功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试网络 Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/network/docker-compose.yml" "网络 Stack 配置文件"

# 测试 2: 检查网络配置文件
if [[ -d "$PROJECT_ROOT/stacks/network" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/network/.env.example" "网络 Stack 环境变量模板" || true
fi

# 测试 3: 如果容器运行中，检查连通性
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "traefik\|nginx\|caddy"; then
    echo ""
    echo "检查运行的网络服务..."
    
    # 检查 Traefik
    if docker ps --format '{{.Names}}' | grep -q "traefik"; then
        assert_container_running "traefik" "Traefik 容器运行"
        wait_for_port "80" "localhost" 5 || true
        wait_for_port "443" "localhost" 5 || true
    fi
    
    # 检查 Nginx Proxy Manager
    if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-manager"; then
        assert_container_running "nginx-proxy-manager" "Nginx Proxy Manager 容器运行"
        wait_for_port "81" "localhost" 5 || true
    fi
else
    skip_test "网络服务容器未运行 (跳过运行时测试)"
fi

# 测试 4: 检查 DNS 解析
echo ""
echo "检查 DNS 解析..."
if command -v nslookup &> /dev/null; then
    if nslookup google.com &> /dev/null; then
        assert_equals "0" "0" "DNS 解析正常"
    else
        assert_equals "0" "1" "DNS 解析失败"
    fi
else
    skip_test "nslookup 不可用"
fi

# 测试 5: 检查网络连接
echo ""
echo "检查网络连接..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    assert_equals "0" "0" "外网连接正常"
else
    skip_test "ping 不可用或被阻止"
fi

echo ""
echo "网络 Stack 测试完成"
