#!/bin/bash
# 网络服务栈测试脚本

set -e

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== 网络服务栈测试开始 ===${NC}"

# 检查 Docker 服务
echo -e "${YELLOW}[1/7] 检查 Docker 服务...${NC}"
if docker ps > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Docker 服务正常${NC}"
else
    echo -e "  ${RED}✗ Docker 服务异常${NC}"
    exit 1
fi

# 检查 Docker Compose 版本
echo -e "${YELLOW}[2/7] 检查 Docker Compose...${NC}"
if docker-compose version > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Docker Compose 可用${NC}"
else
    echo -e "  ${RED}✗ Docker Compose 不可用${NC}"
    exit 1
fi

# 检查 53 端口占用
echo -e "${YELLOW}[3/7] 检查 53 端口占用...${NC}"
if ss -lpn | grep -E ':53\b' | grep -v systemd-resolved > /dev/null; then
    echo -e "  ${RED}✗ 53 端口被占用:${NC}"
    ss -lpn | grep -E ':53\b'
    echo -e "  ${YELLOW}建议运行: sudo ./fix-dns-port.sh --apply${NC}"
else
    echo -e "  ${GREEN}✓ 53 端口可用${NC}"
fi

# 启动服务
echo -e "${YELLOW}[4/7] 启动网络服务栈...${NC}"
docker-compose up -d
sleep 10

# 检查服务状态
echo -e "${YELLOW}[5/7] 检查服务状态...${NC}"
services=("adguard" "wireguard" "unbound" "nginx-proxy-manager" "cloudflare-ddns")

for service in "${services[@]}"; do
    if docker ps --filter "name=$service" --format "{{.Status}}" | grep -q "Up"; then
        echo -e "  ${GREEN}✓ $service 运行正常${NC}"
    else
        echo -e "  ${RED}✗ $service 启动失败${NC}"
        docker-compose logs "$service" --tail=20
    fi
done

# 测试服务连通性
echo -e "${YELLOW}[6/7] 测试服务连通性...${NC}"

# 测试 AdGuard Home
echo -e "  ${YELLOW}测试 AdGuard Home...${NC}"
if curl -f http://localhost:80/ > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓ AdGuard Home Web 界面可访问${NC}"
else
    echo -e "    ${RED}✗ AdGuard Home Web 界面不可访问${NC}"
fi

# 测试 WireGuard Web UI
echo -e "  ${YELLOW}测试 WireGuard Web UI...${NC}"
if curl -f http://localhost:51821/ > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓ WireGuard Web UI 可访问${NC}"
else
    echo -e "    ${RED}✗ WireGuard Web UI 不可访问${NC}"
fi

# 测试 Nginx Proxy Manager
echo -e "  ${YELLOW}测试 Nginx Proxy Manager...${NC}"
if curl -f http://localhost:81/ > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓ Nginx Proxy Manager 可访问${NC}"
else
    echo -e "    ${RED}✗ Nginx Proxy Manager 不可访问${NC}"
fi

# 测试 DNS 解析
echo -e "  ${YELLOW}测试 DNS 解析...${NC}"
if docker exec adguard dig @127.0.0.1 google.com +short > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓ AdGuard Home DNS 解析正常${NC}"
else
    echo -e "    ${RED}✗ AdGuard Home DNS 解析失败${NC}"
fi

# 生成测试报告
echo -e "${YELLOW}[7/7] 生成测试报告...${NC}"
cat > test-report.txt << EOF
=== 网络服务栈测试报告 ===
测试时间: $(date)
测试结果: $(if docker ps | grep -q "Up"; then echo "通过"; else echo "失败"; fi)

服务状态:
$(docker-compose ps)

端口占用:
$(ss -lpn | grep -E ':53|:80|:443|:51820|:51821' || true)

DNS 解析测试:
$(docker exec adguard dig @127.0.0.1 google.com +time=2 2>/dev/null || echo "DNS 测试失败")

日志摘要:
$(docker-compose logs --tail=5 2>/dev/null || true)
EOF

echo -e "  ${GREEN}✓ 测试报告已生成: test-report.txt${NC}"

echo -e "\n${GREEN}=== 测试完成 ===${NC}"
echo -e "所有服务已启动，测试报告已保存到 test-report.txt"
echo -e "\n${YELLOW}下一步操作:${NC}"
echo -e "1. 访问 AdGuard Home: http://localhost:80"
echo -e "2. 访问 WireGuard Web UI: http://localhost:51821"
echo -e "3. 访问 Nginx Proxy Manager: http://localhost:81"
echo -e "4. 查看详细日志: docker-compose logs -f"
echo -e "\n${YELLOW}停止服务: docker-compose down${NC}"