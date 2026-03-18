#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# diagnose.sh — 一键诊断工具
#
# 收集系统、Docker、网络、容器等诊断信息
# 输出到文件或stdout，用于issue提交
#
# 用法: ./scripts/diagnose.sh [--output report.txt]
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 输出文件
OUTPUT_FILE="${1:-diagnose-report-$(date +%Y%m%d-%H%M%S).txt}"

# ═══════════════════════════════════════════════════════════════════════════
# 收集函数
# ═══════════════════════════════════════════════════════════════════════════

collect_section() {
  local title="$1"
  local cmd="$2"

  echo "════════════════════════════════════════════════════════════"
  echo "📌 $title"
  echo "════════════════════════════════════════════════════════════"
  eval "$cmd" 2>/dev/null || echo "无法获取信息"
  echo
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  echo "╔════════════════════════════════════════════════════╗"
  echo "║     Homelab Stack — 系统诊断报告                  ║"
  echo "╚════════════════════════════════════════════════════╝"
  echo "生成时间: $(date)"
  echo "主机名: $(hostname)"
  echo "用户: $(whoami)"
  echo

  {
    collect_section "系统信息" "uname -a && echo && lsb_release -a 2>/dev/null || cat /etc/os-release 2>/dev/null"

    collect_section "资源概览" "free -h && echo && df -hT | head -10"

    collect_section "Docker 版本" "docker --version && docker compose version && docker info | head -20"

    collect_section "Docker 镜像列表" "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | head -20"

    collect_section "运行中的容器" "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"

    collect_section "所有容器 (包括停止)" "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | head -30"

    collect_section "Docker 网络" "docker network ls --format 'table {{.Name}}\t{{.Driver}}'"

    collect_section "Docker 卷" "docker volume ls --format 'table {{.Name}}\t{{.Driver}}' | head -20"

    collect_section "最近容器日志 (错误)" '
      for c in $(docker ps --format "{{.Names}}" 2>/dev/null | head -10); do
        echo "=== $c ==="
        docker logs --tail 50 "$c" 2>&1 | grep -i -E "error|fatal|exception|panic" | head -10 || echo "无错误日志"
      done
    '

    collect_section "Docker 守护进程日志 (最近 50 行)" "journalctl -u docker -n 50 2>/dev/null || dmesg | grep docker | tail -20 || echo '无法获取日志'"

    collect_section "配置文件校验" "
      echo '--- Docker daemon.json ---'
      cat /etc/docker/daemon.json 2>/dev/null || echo '文件不存在'
      echo
      echo '--- .env 文件 ---'
      if [[ -f .env ]]; then
        grep -v '^#' .env | grep -v '^$' | head -20
      else
        echo '.env 文件不存在'
      fi
    "

    collect_section "网络连通性测试" "
      echo '测试 Docker Hub...'
      timeout 5 nc -z hub.docker.com 443 && echo '✓ 可达' || echo '✗ 不可达'
      echo '测试 GitHub...'
      timeout 5 nc -z github.com 443 && echo '✓ 可达' || echo '✗ 不可达'
      echo '测试 gcr.io...'
      timeout 5 nc -z gcr.io 443 && echo '✓ 可达' || echo '✗ 不可达'
      echo '测试 ghcr.io...'
      timeout 5 nc -z ghcr.io 443 && echo '✓ 可达' || echo '✗ 不可达'
    "

    collect_section "系统日志 (最近错误)" "
      echo '--- syslog errors (last 50) ---'
      tail -50 /var/log/syslog 2>/dev/null | grep -i error | head -10 || echo '无错误'
      echo '--- dmesg errors (last 20) ---'
      dmesg | tail -20 | grep -i error || echo '无错误'
    "

    collect_section "磁盘 I/O 性能" "iostat -dx 1 3 2>/dev/null || echo 'iostat 未安装'"

    collect_section "DNS 解析测试" "
      echo '测试域名解析...'
      time nslookup google.com 2>/dev/null | head -10
      time nslookup github.com 2>/dev/null | head -10
    "

    collect_section "防火墙状态" "
      if command -v ufw &>/dev/null; then
        echo '--- UFW ---'
        ufw status verbose
      elif command -v firewall-cmd &>/dev/null; then
        echo '--- firewalld ---'
        firewall-cmd --list-all
      elif command -v iptables &>/dev/null; then
        echo '--- iptables ---'
        iptables -L -n | head -20
      else
        echo '未检测到防火墙'
      fi
    "

    collect_section "当前 Docker Compose 项目" "
      cd '$BASE_DIR' 2>/dev/null || echo '无法进入项目目录'
      docker compose ls 2>/dev/null || echo '无 compose 项目'
      docker compose ps 2>/dev/null || echo '无运行的服务'
    "

    collect_section "资源使用 TOP 10 进程" "ps aux --sort=-%cpu | head -11 && echo && ps aux --sort=-%mem | head -11"

  } | tee "$OUTPUT_FILE"

  echo
  echo "════════════════════════════════════════════════════════════"
  echo "📄 诊断报告已保存到: $OUTPUT_FILE"
  echo "════════════════════════════════════════════════════════════"
  echo
  echo "💡 下一步:"
  echo "  1. 检查报告中的错误和警告"
  echo "  2. 如有问题，搜索错误信息或提交 issue"
  echo "  3. 将报告内容粘贴到 issue 中以便排查"
  echo
}

main "$@"