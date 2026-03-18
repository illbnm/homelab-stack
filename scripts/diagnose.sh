#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — 一键诊断报告
# =============================================================================

set -euo pipefail

REPORT="diagnose-report.txt"

{
echo "=============================================="
echo "  HomeLab Stack 诊断报告"
echo "  生成时间: $(date)"
echo "=============================================="
echo ""

# System info
echo "## 系统信息"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Arch: $(uname -m)"
echo "Memory: $(free -h | awk '/Mem:/ {print $2}') total, $(free -h | awk '/Mem:/ {print $3}') used"
echo "Disk: $(df -h / | awk 'NR==2 {print $2}') total, $(df -h / | awk 'NR==2 {print $3}') used, $(df -h / | awk 'NR==2 {print $4}') free"
echo ""

# Docker info
echo "## Docker"
docker --version 2>/dev/null || echo "Docker: NOT INSTALLED"
docker compose version 2>/dev/null || echo "Docker Compose: NOT INSTALLED"
echo ""

# Container status
echo "## 容器状态"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "无法获取容器状态"
echo ""

# Unhealthy containers
echo "## 不健康容器"
docker ps --filter "health=unhealthy" --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "无"
echo ""

# Recent errors
echo "## 近期错误日志 (最近 1 小时)"
docker ps -q 2>/dev/null | head -20 | while read -r id; do
  name=$(docker inspect --format '{{.Name}}' "$id" 2>/dev/null | tr -d '/')
  errors=$(docker logs --since 1h "$id" 2>&1 | grep -i "error\|fatal\|panic" | tail -5)
  if [[ -n "$errors" ]]; then
    echo "--- ${name} ---"
    echo "$errors"
    echo ""
  fi
done

# Network
echo "## Docker 网络"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null
echo ""

# Disk usage
echo "## Docker 磁盘使用"
docker system df 2>/dev/null
echo ""

# Connectivity
echo "## 网络连通性"
for host in hub.docker.com github.com gcr.io ghcr.io; do
  if curl -sf --connect-timeout 3 -o /dev/null "https://${host}" 2>/dev/null; then
    echo "  [OK]   ${host}"
  else
    echo "  [FAIL] ${host}"
  fi
done

echo ""
echo "=============================================="
echo "  诊断完成"
echo "=============================================="
} | tee "$REPORT"

echo ""
echo "报告已保存到: ${REPORT}"
echo "提 issue 时请附上此文件"
