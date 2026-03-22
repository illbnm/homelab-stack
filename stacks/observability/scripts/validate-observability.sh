#!/bin/bash

# Observability Stack Validation Script
# 用于验证观测性栈部署是否成功

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
WARNINGS=0

echo "=== Observability Stack Validation ==="
echo ""

# 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed or not in PATH${NC}"
    exit 1
fi

# 检查 docker-compose 是否可用
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    exit 1
fi

echo "1. Checking Container Status..."
echo ""

# 定义需要检查的容器
CONTAINERS=("prometheus" "grafana" "loki" "promtail" "tempo" "alertmanager" "cadvisor" "node-exporter" "uptime-kuma" "grafana-oncall")

for container in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${GREEN}✓ Container ${container} is running${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Container ${container} is NOT running${NC}"
        ((FAILED++))
    fi
done

echo ""
echo "2. Checking Service Health Endpoints..."
echo ""

# 检查 Prometheus
if curl -s http://localhost:9090/-/healthy | grep -q "Prometheus Server is Healthy"; then
    echo -e "${GREEN}✓ Prometheus is healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Prometheus health check failed${NC}"
    ((FAILED++))
fi

# 检查 Grafana
if curl -s http://localhost:3000/api/health | grep -q '"commit"'; then
    echo -e "${GREEN}✓ Grafana is healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Grafana health check failed${NC}"
    ((FAILED++))
fi

# 检查 Loki
if curl -s http://localhost:3100/ready | grep -q "ready"; then
    echo -e "${GREEN}✓ Loki is ready${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Loki readiness check failed${NC}"
    ((FAILED++))
fi

# 检查 Tempo
if curl -s http://localhost:3200/ready | grep -q "ready"; then
    echo -e "${GREEN}✓ Tempo is ready${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Tempo readiness check failed${NC}"
    ((FAILED++))
fi

# 检查 Alertmanager
if curl -s http://localhost:9093/-/healthy | grep -q "OK"; then
    echo -e "${GREEN}✓ Alertmanager is healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Alertmanager health check failed${NC}"
    ((FAILED++))
fi

# 检查 cAdvisor
if curl -s http://localhost:8080/healthz | grep -q "ok"; then
    echo -e "${GREEN}✓ cAdvisor is healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ cAdvisor health check failed${NC}"
    ((FAILED++))
fi

# 检查 Node Exporter
if curl -s http://localhost:9100/metrics | grep -q "node_"; then
    echo -e "${GREEN}✓ Node Exporter is serving metrics${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Node Exporter metrics check failed${NC}"
    ((FAILED++))
fi

# 检查 Uptime Kuma
if curl -s http://localhost:3001/api/status-page/ok | grep -q '"status"'; then
    echo -e "${GREEN}✓ Uptime Kuma is healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Uptime Kuma health check failed${NC}"
    ((FAILED++))
fi

echo ""
echo "3. Checking Prometheus Targets..."
echo ""

# 检查 Prometheus targets
TARGETS_UP=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
TARGETS_DOWN=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"down"' | wc -l)

if [ "$TARGETS_DOWN" -eq 0 ]; then
    echo -e "${GREEN}✓ All Prometheus targets are UP (${TARGETS_UP} targets)${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Some Prometheus targets are DOWN (${TARGETS_DOWN} down)${NC}"
    ((FAILED++))
fi

echo ""
echo "4. Checking Data Sources in Grafana..."
echo ""

# 检查 Grafana 数据源 (需要认证，这里做简单检查)
if curl -s http://localhost:3000/api/datasources | grep -q '"name"'; then
    echo -e "${GREEN}✓ Grafana data sources configured${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ Grafana data sources check skipped (requires authentication)${NC}"
    ((WARNINGS++))
fi

echo ""
echo "=== Validation Summary ==="
echo ""
echo -e "Passed:   ${GREEN}${PASSED}${NC}"
echo -e "Failed:   ${RED}${FAILED}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the logs.${NC}"
    exit 1
fi
