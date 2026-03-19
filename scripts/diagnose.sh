#!/usr/bin/env bash
# diagnose.sh — 一键诊断系统问题

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${BLUE}=== homelab-stack 系统诊断 ===${NC}"

# 收集诊断信息
REPORT="/tmp/diagnose-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$REPORT") 2>&1

echo "时间: $(date)"
echo "主机: $(hostname)"
echo "系统: $(uname -a)"
echo

# 1. Docker 状态
echo -e "${CYAN}[1/8] Docker 状态${NC}"
if command -v docker &>/dev/null; then
  docker version | head -2
  docker info --format '{{.ServerVersion}} {{.OperatingSystem}} {{.DockerRootDir}}' || true
  echo "✅ Docker 运行中"
else
  echo "❌ Docker 未安装"
fi
echo

# 2. Docker Compose
echo -e "${CYAN}[2/8] Docker Compose${NC}"
if docker compose version &>/dev/null; then
  docker compose version
  echo "✅ Docker Compose 插件可用"
else
  echo "❌ Docker Compose 插件未安装"
fi
echo

# 3. 磁盘空间
echo -e "${CYAN}[3/8] 磁盘空间${NC}"
df -h /var/lib/docker "$BASE_DIR" | tail -n +2
echo

# 4. 内存
echo -e "${CYAN}[4/8] 内存使用${NC}"
free -h || vm_stat | head -5
echo

# 5. 网络
echo -e "${CYAN}[5/8] 网络配置${NC}"
ip route | grep default || route -n get default
echo "DNS 服务器:"
cat /etc/resolv.conf
echo

# 6. 容器状态
echo -e "${CYAN}[6/8] 运行中的容器${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
echo

# 7. 镜像
echo -e "${CYAN}[7/8] Docker 镜像 (前 10)${NC}"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -10
echo

# 8. 日志检查
echo -e "${CYAN}[8/8] 最近错误日志${NC}"
echo "----- docker logs (最近 container) -----"
docker ps --format "{{.Names}}" | head -5 | xargs -I{} sh -c 'echo "=== {} ==="; docker logs {} 2>&1 | grep -i error || echo "No errors"' 2>/dev/null || true

echo
echo "=== 诊断完成 ==="
echo "报告已保存: $REPORT"
echo

# 建议
echo -e "${YELLOW}常见问题排查:${NC}"
echo "1. 端口冲突: ss -tuln | grep :80"
echo "2. 权限问题: ls -la /var/run/docker.sock"
echo "3. 镜像拉取失败: docker pull <image> (查看具体 error)"
echo "4. 网络不通: bash scripts/check-connectivity.sh"
echo "5. 查看详细日志: docker compose -f stacks/<stack>/docker-compose.yml logs -f"