#!/bin/bash

# AI Stack 健康检查脚本
# 用于验证所有服务是否正常运行

set -e

echo "=========================================="
echo "AI Stack 健康检查"
echo "=========================================="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "检查 $name... "
    
    if curl -sf --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 正常${NC}"
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        return 1
    fi
}

# 等待服务启动
echo ""
echo "等待服务启动 (30 秒)..."
sleep 30

# 检查 Docker 容器状态
echo ""
echo "Docker 容器状态:"
docker compose ps

# 检查各服务
echo ""
echo "服务健康检查:"
echo "------------------------------------------"

# Ollama
check_service "Ollama" "http://localhost:11434/api/tags"

# Open WebUI
check_service "Open WebUI" "http://localhost:3000/health"

# Stable Diffusion
check_service "Stable Diffusion" "http://localhost:7860/docs"

# Perplexica
check_service "Perplexica" "http://localhost:3080/"

echo ""
echo "=========================================="
echo "健康检查完成"
echo "=========================================="

# Ollama 模型测试
echo ""
echo "Ollama 模型测试:"
echo "------------------------------------------"
docker exec ollama ollama list || echo "⚠️  暂无模型，请通过 WebUI 或命令行拉取"

echo ""
echo "访问地址:"
echo "  - Open WebUI:      http://localhost:3000"
echo "  - Stable Diffusion: http://localhost:7860"
echo "  - Perplexica:      http://localhost:3080"
echo "  - Ollama API:      http://localhost:11434"
echo ""
