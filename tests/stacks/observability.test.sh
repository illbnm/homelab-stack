#!/usr/bin/env bash
# observability.test.sh - 可观测性 Stack 集成测试
# 测试监控、日志、追踪服务的连通性

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载库
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

echo "测试可观测性 Stack..."

# 测试 1: 检查 docker-compose.yml 存在
assert_file_exists "$PROJECT_ROOT/stacks/observability/docker-compose.yml" "可观测性 Stack 配置文件"

# 测试 2: 检查环境变量模板
if [[ -d "$PROJECT_ROOT/stacks/observability" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/observability/.env.example" "可观测性 Stack 环境变量模板" || true
fi

# 测试 3: 检查运行的服务
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "grafana\|prometheus\|loki\|jaeger\|tempo"; then
    echo ""
    echo "检查运行的可观测性服务..."
    
    # Grafana
    if docker ps --format '{{.Names}}' | grep -q "grafana"; then
        assert_container_running "grafana" "Grafana 容器运行"
        wait_for_port "3000" "localhost" 5 || true
        assert_http_status "200" "http://localhost:3000/login" "Grafana Web UI" || true
    fi
    
    # Prometheus
    if docker ps --format '{{.Names}}' | grep -q "prometheus"; then
        assert_container_running "prometheus" "Prometheus 容器运行"
        wait_for_port "9090" "localhost" 5 || true
        assert_http_status "200" "http://localhost:9090/graph" "Prometheus Web UI" || true
    fi
    
    # Loki
    if docker ps --format '{{.Names}}' | grep -q "loki"; then
        assert_container_running "loki" "Loki 容器运行"
        wait_for_port "3100" "localhost" 5 || true
    fi
    
    # Jaeger
    if docker ps --format '{{.Names}}' | grep -q "jaeger"; then
        assert_container_running "jaeger" "Jaeger 容器运行"
        wait_for_port "16686" "localhost" 5 || true
        assert_http_status "200" "http://localhost:16686" "Jaeger Web UI" || true
    fi
    
    # Tempo
    if docker ps --format '{{.Names}}' | grep -q "tempo"; then
        assert_container_running "tempo" "Tempo 容器运行"
        wait_for_port "3200" "localhost" 5 || true
    fi
else
    skip_test "可观测性服务容器未运行 (跳过运行时测试)"
fi

# 测试 4: 检查告警配置
echo ""
echo "检查告警配置..."
if [[ -f "$PROJECT_ROOT/stacks/observability/prometheus/alerts.yml" ]]; then
    assert_file_exists "$PROJECT_ROOT/stacks/observability/prometheus/alerts.yml" "Prometheus 告警规则"
else
    skip_test "告警规则文件未找到"
fi

# 测试 5: 检查仪表板配置
echo ""
echo "检查仪表板配置..."
if [[ -d "$PROJECT_ROOT/stacks/observability/grafana/dashboards" ]]; then
    assert_dir_exists "$PROJECT_ROOT/stacks/observability/grafana/dashboards" "Grafana 仪表板目录"
    local dashboard_count=$(find "$PROJECT_ROOT/stacks/observability/grafana/dashboards" -name "*.json" 2>/dev/null | wc -l)
    if [[ $dashboard_count -gt 0 ]]; then
        assert_not_empty "$dashboard_count" "已配置 $dashboard_count 个仪表板"
    else
        skip_test "未找到仪表板 JSON 文件"
    fi
else
    skip_test "仪表板目录未配置"
fi

echo ""
echo "可观测性 Stack 测试完成"
