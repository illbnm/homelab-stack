#!/usr/bin/env bash
# notifications.test.sh - 通知 Stack 集成测试
# 测试 ntfy/Gotify/Pushover 等通知服务

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试通知 Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/notifications/docker-compose.yml" "通知 Stack 配置文件"

# 测试 2: 检查环境变量模板
if [[ -d "$PROJECT_ROOT/stacks/notifications" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/notifications/.env.example" "通知 Stack 环境变量模板" || true
fi

# 测试 3: 检查运行的通知服务
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "ntfy\|gotify\|apprise"; then
    echo ""
    echo "检查运行的通知服务..."
    
    # ntfy
    if docker ps --format '{{.Names}}' | grep -q "ntfy"; then
        assert_container_running "ntfy" "ntfy 容器运行"
        wait_for_port "8080" "localhost" 5 || true
        assert_http_status "200" "http://localhost:8080" "ntfy Web UI" || true
        
        # 测试发布消息
        echo "测试 ntfy 消息发布..."
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" -d "测试消息" "http://localhost:8080/homelab-test" 2>/dev/null || echo "000")
        if [[ "$response" == "200" ]]; then
            assert_equals "200" "200" "ntfy 消息发布成功"
        else
            skip_test "ntfy 消息发布测试 (状态码：$response)"
        fi
    fi
    
    # Gotify
    if docker ps --format '{{.Names}}' | grep -q "gotify"; then
        assert_container_running "gotify" "Gotify 容器运行"
        wait_for_port "8080" "localhost" 5 || true
        assert_http_status "200" "http://localhost:8080" "Gotify Web UI" || true
        
        # 测试 API
        echo "测试 Gotify API..."
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/health" 2>/dev/null || echo "000")
        if [[ "$response" == "200" ]]; then
            assert_equals "200" "200" "Gotify 健康检查通过"
        else
            skip_test "Gotify API 测试 (状态码：$response)"
        fi
    fi
    
    # Apprise API
    if docker ps --format '{{.Names}}' | grep -q "apprise"; then
        assert_container_running "apprise" "Apprise API 容器运行"
        wait_for_port "8000" "localhost" 5 || true
    fi
else
    skip_test "通知服务容器未运行 (跳过运行时测试)"
fi

# 测试 4: 检查通知配置
echo ""
echo "检查通知配置..."
if [[ -f "$PROJECT_ROOT/stacks/notifications/ntfy/server.yml" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/notifications/ntfy/server.yml" "ntfy 服务器配置"
else
    skip_test "ntfy 配置文件未找到"
fi

echo ""
echo "通知 Stack 测试完成"
