#!/usr/bin/env bash
# =============================================================================
# Diagnose — 一键诊断脚本
# 收集系统信息、Docker 状态、日志、网络连通性等，生成诊断报告
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[diagnose]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[diagnose]${NC} $*" >&2; }
log_error() { echo -e "${RED}[diagnose]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[diagnose]${NC} $*"; }

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$ROOT_DIR/diagnose-report.txt"

# 开始收集信息
start_report() {
  cat > "$REPORT_FILE" << EOF
================================================================================
HomeLab Stack 诊断报告
生成时间：$(date '+%Y-%m-%d %H:%M:%S %Z')
主机名：$(hostname)
================================================================================

EOF
  log_info "开始生成诊断报告：$REPORT_FILE"
}

# 添加章节
add_section() {
  local title="$1"
  echo "" >> "$REPORT_FILE"
  echo "================================================================================" >> "$REPORT_FILE"
  echo "$title" >> "$REPORT_FILE"
  echo "================================================================================" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

# 收集系统信息
collect_system_info() {
  add_section "1. 系统信息"
  
  echo "操作系统:" >> "$REPORT_FILE"
  if [[ -f /etc/os-release ]]; then
    cat /etc/os-release | grep -E "^(NAME|VERSION|PRETTY_NAME)=" >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "内核版本:" >> "$REPORT_FILE"
  uname -r >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  echo "系统架构:" >> "$REPORT_FILE"
  uname -m >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  echo "运行时间:" >> "$REPORT_FILE"
  uptime -p >> "$REPORT_FILE" 2>/dev/null || uptime >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

# 收集硬件信息
collect_hardware_info() {
  add_section "2. 硬件信息"
  
  echo "CPU 信息:" >> "$REPORT_FILE"
  if command -v lscpu &>/dev/null; then
    lscpu | grep -E "^(Architecture|CPU\(s\)|Model name):" >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  else
    nproc 2>/dev/null >> "$REPORT_FILE" || echo "  未知" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "内存信息:" >> "$REPORT_FILE"
  if command -v free &>/dev/null; then
    free -h | grep -E "^Mem:" >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  elif [[ -f /proc/meminfo ]]; then
    grep -E "^(MemTotal|MemFree|MemAvailable):" /proc/meminfo >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "磁盘空间:" >> "$REPORT_FILE"
  df -h "$ROOT_DIR" 2>/dev/null | tail -1 >> "$REPORT_FILE" || echo "  未知" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  echo "Docker 磁盘使用:" >> "$REPORT_FILE"
  if command -v docker &>/dev/null; then
    docker system df 2>/dev/null | head -5 >> "$REPORT_FILE" || echo "  无法获取" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# 收集 Docker 信息
collect_docker_info() {
  add_section "3. Docker 信息"
  
  echo "Docker 版本:" >> "$REPORT_FILE"
  if command -v docker &>/dev/null; then
    docker --version >> "$REPORT_FILE" 2>/dev/null || echo "  未安装" >> "$REPORT_FILE"
  else
    echo "  未安装" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "Docker Compose 版本:" >> "$REPORT_FILE"
  if command -v docker &>/dev/null; then
    docker compose version >> "$REPORT_FILE" 2>/dev/null || docker-compose version >> "$REPORT_FILE" 2>/dev/null || echo "  未安装" >> "$REPORT_FILE"
  else
    echo "  未安装" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "Docker 信息:" >> "$REPORT_FILE"
  if command -v docker &>/dev/null; then
    docker info --format "容器数：{{.Containers}} (运行：{{.ContainersRunning}}, 暂停：{{.ContainersPaused}}, 停止：{{.ContainersStopped}})" >> "$REPORT_FILE" 2>/dev/null || echo "  无法获取" >> "$REPORT_FILE"
    docker info --format "镜像数：{{.Images}}" >> "$REPORT_FILE" 2>/dev/null || echo "  无法获取" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "Docker 存储驱动:" >> "$REPORT_FILE"
  if command -v docker &>/dev/null; then
    docker info --format "{{.Driver}}" >> "$REPORT_FILE" 2>/dev/null || echo "  未知" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# 收集容器状态
collect_container_status() {
  add_section "4. 容器状态"
  
  if command -v docker &>/dev/null; then
    echo "所有容器:" >> "$REPORT_FILE"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "$REPORT_FILE" 2>/dev/null || echo "  无容器" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "健康检查状态:" >> "$REPORT_FILE"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}" >> "$REPORT_FILE" 2>/dev/null || echo "  无健康检查" >> "$REPORT_FILE"
  else
    echo "Docker 未安装" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# 收集近期错误日志
collect_error_logs() {
  add_section "5. 近期错误日志"
  
  if command -v docker &>/dev/null; then
    echo "最近 10 个容器的最后 20 行日志:" >> "$REPORT_FILE"
    local containers
    containers=$(docker ps -q --latest 10 2>/dev/null || echo "")
    
    if [[ -n "$containers" ]]; then
      for container in $containers; do
        local name
        name=$(docker inspect --format '{{.Name}}' "$container" 2>/dev/null | sed 's/^\///')
        echo "" >> "$REPORT_FILE"
        echo "--- $name ---" >> "$REPORT_FILE"
        docker logs --tail 20 "$container" 2>&1 | head -20 >> "$REPORT_FILE" || echo "  无法获取日志" >> "$REPORT_FILE"
      done
    else
      echo "  无运行中的容器" >> "$REPORT_FILE"
    fi
  else
    echo "Docker 未安装" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# 收集网络连通性测试结果
collect_network_test() {
  add_section "6. 网络连通性测试"
  
  local check_script="$SCRIPT_DIR/check-connectivity.sh"
  if [[ -x "$check_script" ]]; then
    log_step "运行网络连通性测试..."
    $check_script >> "$REPORT_FILE" 2>&1 || echo "  测试失败" >> "$REPORT_FILE"
  else
    echo "连通性测试脚本不存在：$check_script" >> "$REPORT_FILE"
    
    # 简单测试
    echo "简单测试:" >> "$REPORT_FILE"
    for host in "www.baidu.com" "hub.docker.com" "github.com"; do
      if curl -sf --connect-timeout 3 "https://$host" &>/dev/null; then
        echo "  [OK] $host" >> "$REPORT_FILE"
      else
        echo "  [FAIL] $host" >> "$REPORT_FILE"
      fi
    done
  fi
  echo "" >> "$REPORT_FILE"
}

# 收集配置文件校验
collect_config_validation() {
  add_section "7. 配置文件校验"
  
  echo "环境变量文件:" >> "$REPORT_FILE"
  if [[ -f "$ROOT_DIR/.env" ]]; then
    echo "  ✓ .env 存在" >> "$REPORT_FILE"
    # 检查关键变量
    for var in "PUID" "PGID" "TZ" "DOMAIN"; do
      if grep -q "^$var=" "$ROOT_DIR/.env" 2>/dev/null; then
        echo "    ✓ $var 已设置" >> "$REPORT_FILE"
      else
        echo "    ✗ $var 未设置" >> "$REPORT_FILE"
      fi
    done
  else
    echo "  ✗ .env 不存在" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "Stack 配置文件:" >> "$REPORT_FILE"
  local stack_dir="$ROOT_DIR/stacks"
  if [[ -d "$stack_dir" ]]; then
    local count=0
    for stack in "$stack_dir"/*/; do
      if [[ -f "${stack}docker-compose.yml" || -f "${stack}docker-compose.local.yml" ]]; then
        local stack_name=$(basename "$stack")
        echo "  ✓ $stack_name" >> "$REPORT_FILE"
        ((count++))
      fi
    done
    echo "共找到 $count 个 stack" >> "$REPORT_FILE"
  else
    echo "  ✗ stacks 目录不存在" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
  
  echo "镜像配置文件:" >> "$REPORT_FILE"
  if [[ -f "$ROOT_DIR/config/cn-mirrors.yml" ]]; then
    echo "  ✓ cn-mirrors.yml 存在" >> "$REPORT_FILE"
  else
    echo "  ✗ cn-mirrors.yml 不存在" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# 完成报告
finish_report() {
  add_section "8. 建议操作"
  
  echo "根据诊断结果，建议执行以下操作：" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  # 检查 Docker 是否运行
  if ! command -v docker &>/dev/null; then
    echo "1. 安装 Docker:" >> "$REPORT_FILE"
    echo "   curl -fsSL https://get.docker.com | bash" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  fi
  
  # 检查网络
  if ! curl -sf --connect-timeout 3 "https://hub.docker.com" &>/dev/null; then
    echo "2. 配置国内镜像加速:" >> "$REPORT_FILE"
    echo "   ./scripts/setup-cn-mirrors.sh" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  fi
  
  # 检查环境变量
  if [[ ! -f "$ROOT_DIR/.env" ]]; then
    echo "3. 配置环境变量:" >> "$REPORT_FILE"
    echo "   cp .env.example .env" >> "$REPORT_FILE"
    echo "   # 编辑 .env 文件填写配置" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  fi
  
  echo "4. 运行安装脚本:" >> "$REPORT_FILE"
  echo "   ./install.sh" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  echo "================================================================================" >> "$REPORT_FILE"
  echo "报告结束" >> "$REPORT_FILE"
  echo "================================================================================" >> "$REPORT_FILE"
}

# 显示报告
show_report() {
  echo ""
  log_info "诊断报告已生成：$REPORT_FILE"
  echo ""
  echo "=============================================="
  echo "  诊断报告摘要"
  echo "=============================================="
  echo ""
  
  # 显示关键信息
  head -50 "$REPORT_FILE"
  
  echo ""
  echo "..."
  echo ""
  echo "完整报告请查看：$REPORT_FILE"
  echo ""
}

# 主函数
main() {
  echo ""
  echo "=============================================="
  echo "  HomeLab Stack 一键诊断工具"
  echo "=============================================="
  echo ""
  
  log_step "开始收集诊断信息..."
  
  start_report
  collect_system_info
  collect_hardware_info
  collect_docker_info
  collect_container_status
  collect_error_logs
  collect_network_test
  collect_config_validation
  finish_report
  
  show_report
  
  log_info "诊断完成！"
}

main "$@"
