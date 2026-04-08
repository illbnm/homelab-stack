#!/usr/bin/env bash
# =============================================================================
# System Diagnostic Tool
# Collects diagnostic information for troubleshooting
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

OUTPUT_FILE="diagnose-report.txt"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Initialize report
init_report() {
  cat > "$OUTPUT_FILE" <<EOF
===============================================================================
                    HomeLab Stack 诊断报告
===============================================================================
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
主机名: $(hostname)
用户: $(whoami)

EOF
}

# Append section to report
append_section() {
  local title=$1
  local content=$2

  cat >> "$OUTPUT_FILE" <<EOF

===============================================================================
$title
===============================================================================
$content

EOF
}

# Collect system information
collect_system_info() {
  log_info "收集系统信息..."

  local info
  info=$(cat <<EOF
操作系统: $(lsb_release -d 2>/dev/null | cut -f2 || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d\" -f2 || uname -s)
内核版本: $(uname -r)
架构: $(uname -m)
运行时间: $(uptime -p 2>/dev/null || uptime)

CPU:
$(lscpu | grep -E 'Model name|CPU\(s\)|CPU MHz' 2>/dev/null || echo "  无法获取 CPU 信息")

内存:
$(free -h 2>/dev/null || echo "  无法获取内存信息")

磁盘:
$(df -h / /var/lib/docker 2>/dev/null | head -5 || echo "  无法获取磁盘信息")

网络接口:
$(ip -brief addr show 2>/dev/null | head -5 || ifconfig 2>/dev/null | grep -E '^[a-z]' | head -5 || echo "  无法获取网络信息")
EOF
)

  append_section "系统信息" "$info"
}

# Collect Docker information
collect_docker_info() {
  log_info "收集 Docker 信息..."

  local info
  info=$(cat <<EOF
Docker 版本:
$(docker --version 2>/dev/null || echo "  Docker 未安装")

Docker Compose 版本:
$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "  Docker Compose 未安装")

Docker 状态:
$(systemctl is-active docker 2>/dev/null || echo "  无法检查 Docker 服务状态")

Docker 信息:
$(docker info 2>/dev/null | grep -E 'Server Version|Storage Driver|Cgroup|Operating System|Kernel Version|Total Memory|CPUs' || echo "  无法获取 Docker 详细信息")

Docker 镜像源:
$(docker info 2>/dev/null | grep -A 5 "Registry Mirrors" || echo "  未配置镜像加速")
EOF
)

  append_section "Docker 信息" "$info"
}

# Collect container status
collect_container_status() {
  log_info "收集容器状态..."

  local status
  status=$(cat <<EOF
所有容器:
$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  无容器")

网络:
$(docker network ls 2>/dev/null || echo "  无法列出网络")

卷:
$(docker volume ls 2>/dev/null || echo "  无法列出卷")
EOF
)

  append_section "容器状态" "$status"
}

# Collect error logs
collect_error_logs() {
  log_info "收集错误日志..."

  local logs
  logs=$(cat <<EOF
最近退出的容器 (最多5个):
$(docker ps -a --filter "status=exited" --format "{{.Names}} ({{.Status}})" 2>/dev/null | head -5 || echo "  无退出容器")

最近不健康的容器:
$(docker ps -a --filter "health=unhealthy" --format "{{.Names}} ({{.Status}})" 2>/dev/null | head -5 || echo "  无不健康容器")

Docker 守护进程日志 (最后20行):
$(journalctl -u docker.service --no-pager -n 20 2>/dev/null || echo "  无法访问 Docker 日志")

EOF
)

  # Add logs for unhealthy containers
  local containers
  containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | head -3)

  if [[ -n "$containers" ]]; then
    logs+="\n退出容器日志:\n"
    while IFS= read -r container; do
      [[ -z "$container" ]] && continue
      logs+="\n--- $container (最后30行) ---\n"
      logs+="$(docker logs --tail 30 "$container" 2>&1 || echo "  无法获取日志")\n"
    done <<< "$containers"
  fi

  append_section "错误日志" "$logs"
}

# Collect network connectivity
collect_network_info() {
  log_info "收集网络连通性信息..."

  local network
  network="DNS 解析测试:\n"

  for domain in docker.io github.com gcr.io ghcr.io; do
    if nslookup "$domain" >/dev/null 2>&1; then
      network+="✓ $domain: 可解析\n"
    else
      network+="✗ $domain: 解析失败\n"
    fi
  done

  network+="\n网络连通性测试:\n"

  for url in https://hub.docker.com https://github.com https://gcr.io https://ghcr.io; do
    if curl -sf --connect-timeout 3 --max-time 5 "$url" >/dev/null 2>&1; then
      network+="✓ $url: 可达\n"
    else
      network+="✗ $url: 不可达\n"
    fi
  done

  network+="\n防火墙状态:\n"
  network+="$(ufw status 2>/dev/null || firewall-cmd --state 2>/dev/null || echo "  无法检测防火墙状态")\n"

  network+="\n开放端口:\n"
  network+="$(ss -tlnp 2>/dev/null | grep -E ':(80|443|3000|8080|9000)\s' | head -5 || netstat -tlnp 2>/dev/null | grep -E ':(80|443|3000|8080|9000)\s' | head -5 || echo "  无法列出端口")\n"

  append_section "网络信息" "$network"
}

# Validate configuration files
validate_configs() {
  log_info "验证配置文件..."

  local validation
  validation=""

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

  # Check .env file
  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    validation+="✓ .env 文件存在\n"

    # Check required variables
    local required_vars=("DOMAIN" "ACME_EMAIL" "TZ")
    for var in "${required_vars[@]}"; do
      if grep -q "^${var}=" "$PROJECT_ROOT/.env"; then
        validation+="  ✓ $var 已设置\n"
      else
        validation+="  ✗ $var 未设置\n"
      fi
    done
  else
    validation+="✗ .env 文件不存在\n"
  fi

  # Check acme.json
  if [[ -f "$PROJECT_ROOT/config/traefik/acme.json" ]]; then
    local perms
    perms=$(stat -c '%a' "$PROJECT_ROOT/config/traefik/acme.json" 2>/dev/null || stat -f '%A' "$PROJECT_ROOT/config/traefik/acme.json" 2>/dev/null || echo "unknown")
    if [[ "$perms" == "600" ]]; then
      validation+="✓ acme.json 权限正确 (600)\n"
    else
      validation+="✗ acme.json 权限错误 ($perms, 应为 600)\n"
    fi
  else
    validation+="✗ acme.json 不存在\n"
  fi

  # Check proxy network
  if docker network inspect proxy >/dev/null 2>&1; then
    validation+="✓ proxy 网络存在\n"
  else
    validation+="✗ proxy 网络不存在\n"
  fi

  append_section "配置验证" "$validation"
}

# Main execution
main() {
  echo -e "\n${BOLD}${BLUE}=== HomeLab Stack 诊断工具 ===${NC}\n"

  init_report
  collect_system_info
  collect_docker_info
  collect_container_status
  collect_error_logs
  collect_network_info
  validate_configs

  # Add summary
  cat >> "$OUTPUT_FILE" <<EOF

===============================================================================
                              报告结束
===============================================================================

建议:
1. 如果有容器退出或不健康，检查对应的错误日志
2. 如果网络不可达，考虑运行 ./scripts/setup-cn-mirrors.sh
3. 如果配置验证失败，检查 .env 文件和 acme.json 权限
4. 提交 Issue 时请附带此诊断报告

报告保存至: $OUTPUT_FILE
EOF

  log_info "诊断报告已生成: $OUTPUT_FILE"

  # Display summary
  echo -e "\n${BOLD}摘要:${NC}"
  echo "  系统信息: 已收集"
  echo "  Docker 状态: 已收集"
  echo "  容器状态: 已收集"
  echo "  错误日志: 已收集"
  echo "  网络信息: 已收集"
  echo "  配置验证: 已完成"
  echo
  echo -e "完整报告: ${GREEN}$OUTPUT_FILE${NC}"
}

main "$@"
