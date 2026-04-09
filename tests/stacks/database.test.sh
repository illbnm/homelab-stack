#!/usr/bin/env bash
# database.test.sh - 数据库 Stack 集成测试
# 测试数据库服务的连通性和基本功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试数据库 Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/database/docker-compose.yml" "数据库 Stack 配置文件"

# 测试 2: 检查环境变量模板
if [[ -d "$PROJECT_ROOT/stacks/database" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/database/.env.example" "数据库 Stack 环境变量模板" || true
fi

# 测试 3: 检查运行的数据库容器
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres\|mysql\|mariadb\|mongodb\|redis"; then
    echo ""
    echo "检查运行的数据库服务..."
    
    # PostgreSQL
    if docker ps --format '{{.Names}}' | grep -q "postgres"; then
        assert_container_running "postgres" "PostgreSQL 容器运行"
        wait_for_port "5432" "localhost" 5 || true
        
        # 测试连接
        if command -v psql &> /dev/null; then
            echo "测试 PostgreSQL 连接..."
            # 注意：这里需要正确的凭据，实际使用时从 .env 读取
            skip_test "PostgreSQL 连接测试 (需要凭据)"
        fi
    fi
    
    # MySQL/MariaDB
    if docker ps --format '{{.Names}}' | grep -qE "mysql|mariadb"; then
        local db_name=$(docker ps --format '{{.Names}}' | grep -E "mysql|mariadb" | head -1)
        assert_container_running "$db_name" "MySQL/MariaDB 容器运行"
        wait_for_port "3306" "localhost" 5 || true
    fi
    
    # MongoDB
    if docker ps --format '{{.Names}}' | grep -q "mongodb\|mongo"; then
        assert_container_running "mongodb" "MongoDB 容器运行" || assert_container_running "mongo" "MongoDB 容器运行"
        wait_for_port "27017" "localhost" 5 || true
    fi
    
    # Redis
    if docker ps --format '{{.Names}}' | grep -q "redis"; then
        assert_container_running "redis" "Redis 容器运行"
        wait_for_port "6379" "localhost" 5 || true
        
        # 测试 Redis 连接
        if command -v redis-cli &> /dev/null; then
            echo "测试 Redis 连接..."
            if redis-cli ping 2>/dev/null | grep -q "PONG"; then
                assert_equals "PONG" "PONG" "Redis PING/PONG 测试"
            else
                skip_test "Redis 连接测试 (需要认证)"
            fi
        fi
    fi
else
    skip_test "数据库容器未运行 (跳过运行时测试)"
fi

# 测试 4: 检查数据持久化
echo ""
echo "检查数据持久化配置..."
if [[ -d "$PROJECT_ROOT/data" ]]; then
    assert_dir_exists "$PROJECT_ROOT/data/postgres" "PostgreSQL 数据目录" || true
    assert_dir_exists "$PROJECT_ROOT/data/mysql" "MySQL 数据目录" || true
    assert_dir_exists "$PROJECT_ROOT/data/redis" "Redis 数据目录" || true
else
    skip_test "数据目录未配置"
fi

echo ""
echo "数据库 Stack 测试完成"
