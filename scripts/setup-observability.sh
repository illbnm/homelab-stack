#!/bin/bash
# Observability Stack 自动配置脚本

set -e

echo "🚀 开始配置 Observability Stack..."

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi

# 创建网络
echo "📊 创建 homelab 网络..."
docker network create homelab 2>/dev/null || echo "✅ 网络已存在"

# 进入配置目录
cd "$(dirname "$0")/../config/observability"

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "📝 创建 .env 文件..."
    cat > .env << EOF
ADMIN_USER=admin
ADMIN_PASSWORD=$(openssl rand -base64 12)
ALERT_EMAIL=admin@homelab.local
NTFY_URL=https://ntfy.sh
EOF
    echo "✅ .env 已创建（密码已自动生成）"
    echo "⚠️  请手动修改 ALERT_EMAIL"
fi

# 创建 Prometheus targets 目录
mkdir -p /etc/prometheus/targets

# 启动所有服务
echo "🚀 启动所有服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo ""
echo "📊 服务状态:"
docker-compose ps

# 显示访问信息
echo ""
echo "✅ Observability Stack 已部署!"
echo ""
echo "🌐 访问地址:"
echo "  Grafana:        http://localhost:3000"
echo "  Prometheus:     http://localhost:9090"
echo "  Alertmanager:   http://localhost:9093"
echo "  Uptime Kuma:    http://localhost:3001"
echo "  ntfy:           http://localhost:8090"
echo "  cAdvisor:       http://localhost:8080"
echo ""
echo "📝 下一步:"
echo "  1. 访问 Uptime Kuma 创建管理员账号"
echo "  2. 在 Grafana 中导入 Dashboard (ID: 1860, 893)"
echo "  3. 配置告警通知 (ntfy/Email)"
echo ""
