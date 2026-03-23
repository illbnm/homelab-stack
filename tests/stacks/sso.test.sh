#!/usr/bin/env bash
# sso.test.sh - SSO Stack 集成测试
# 测试 Authentik/SSO 服务的连通性和功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试 SSO Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/sso/docker-compose.yml" "SSO Stack 配置文件"

# 测试 2: 检查环境变量模板
if [[ -d "$PROJECT_ROOT/stacks/sso" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/sso/.env.example" "SSO Stack 环境变量模板" || true
fi

# 测试 3: 检查运行的 SSO 服务
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "authentik\|keycloak\|casdoor"; then
    echo ""
    echo "检查运行的 SSO 服务..."
    
    # Authentik
    if docker ps --format '{{.Names}}' | grep -q "authentik"; then
        assert_container_running "authentik-server" "Authentik Server 容器运行" || \
        assert_container_running "authentik" "Authentik 容器运行"
        
        # 等待端口就绪
        wait_for_port "9000" "localhost" 10 || true
        
        # 检查 Web UI
        assert_http_status "200" "http://localhost:9000/if/flow/initial-setup/" "Authentik Web UI" || \
        assert_http_status "302" "http://localhost:9000" "Authentik 重定向" || true
    fi
    
    # Keycloak
    if docker ps --format '{{.Names}}' | grep -q "keycloak"; then
        assert_container_running "keycloak" "Keycloak 容器运行"
        wait_for_port "8080" "localhost" 10 || true
        assert_http_status "200" "http://localhost:8080" "Keycloak Web UI" || true
    fi
else
    skip_test "SSO 服务容器未运行 (跳过运行时测试)"
fi

# 测试 4: 检查 Redis 依赖 (Authentik 需要)
echo ""
echo "检查 Redis 依赖..."
if docker ps --format '{{.Names}}' | grep -q "authentik-redis\|redis"; then
    assert_container_running "authentik-redis" "Authentik Redis 容器运行" || \
    assert_container_running "redis" "Redis 容器运行 (SSO 依赖)"
else
    skip_test "Redis 容器未运行"
fi

# 测试 5: 检查 PostgreSQL 依赖 (Authentik 需要)
echo ""
echo "检查 PostgreSQL 依赖..."
if docker ps --format '{{.Names}}' | grep -q "authentik-db\|postgres"; then
    assert_container_running "authentik-db" "Authentik PostgreSQL 容器运行" || \
    assert_container_running "postgres" "PostgreSQL 容器运行 (SSO 依赖)"
else
    skip_test "PostgreSQL 容器未运行"
fi

# 测试 6: 检查证书配置
echo ""
echo "检查证书配置..."
if [[ -d "$PROJECT_ROOT/stacks/sso/certs" ]]; then
    assert_dir_exists "$PROJECT_ROOT/stacks/sso/certs" "SSO 证书目录"
else
    skip_test "证书目录未配置 (可能使用自签名证书)"
fi

echo ""
echo "SSO Stack 测试完成"
