#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer (Robust Edition)
# 增强版安装脚本：支持网络重试、磁盘/内存检测、端口冲突检测等
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed."
    log_info "请运行 ./scripts/diagnose.sh 生成诊断报告"
  fi
}
trap cleanup EXIT

# ============================================================================
# 工具函数
# ============================================================================

curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    if curl -sf --connect-timeout 10 --max-time 60 "$@" &>/dev/null; then
      return 0
    fi
    echo "[curl_retry] Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}

# ============================================================================
# 检测: Docker 安装
# ============================================================================
check_docker_install() {
  log_step "Checking Docker installation"

  if command -v docker &>/dev/null; then
    local ver
    ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '0.0.0')
    log_info "Docker 已安装: $ver"
    return 0
  fi

  log_warn "Docker 未安装，正在尝试安装..."

  if command -v apt-get &>/dev/null; then
    log_info "检测到 Debian/Ubuntu 系统"
    curl_retry https://get.docker.com | sh || {
      log_warn "自动安装失败，尝试备用方法..."
      sudo apt-get update
      sudo apt-get install -y docker.io docker-compose
    }
  elif command -v yum &>/dev/null; then
    log_info "检测到 CentOS/RHEL 系统"
    sudo yum install -y docker docker-compose-plugin
  elif command -v pacman &>/dev/null; then
    log_info "检测到 Arch Linux 系统"
    sudo pacman -S docker docker-compose
  else
    log_error "无法自动安装 Docker，请手动安装: https://docs.docker.com/get-docker/"
    return 1
  fi

  sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
  sudo systemctl enable docker 2>/dev/null || true

  if ! command -v docker &>/dev/null; then
    log_error "Docker 安装失败"
    return 1
  fi
  log_info "Docker 安装成功"
}

# ============================================================================
# 检测: Docker 权限
# ============================================================================
check_docker_permissions() {
  log_step "Checking Docker permissions"

  if docker info &>/dev/null; then
    log_info "Docker daemon 可访问"
    return 0
  fi

  log_warn "当前用户无法访问 Docker daemon"

  if groups | grep -q docker; then
    log_warn "用户已在 docker 组但权限未生效，请重新登录"
  else
    log_info "正在将当前用户添加到 docker 组..."
    sudo usermod -aG docker "$USER"
    log_warn "已添加用户到 docker 组，请重新登录后运行此脚本"
  fi
}

# ============================================================================
# 检测: Docker Compose v2
# ============================================================================
check_compose_v2() {
  log_step "Checking Docker Compose v2"

  if docker compose version &>/dev/null; then
    local ver
    ver=$(docker compose version --short 2>/dev/null)
    log_info "Docker Compose v2: $ver"
    return 0
  fi

  if command -v docker-compose &>/dev/null; then
    log_error "检测到 Docker Compose v1，请升级到 v2"
    log_info "  升级方法: https://docs.docker.com/compose/migrate/"
    log_info "  或运行: sudo apt-get remove docker-compose && sudo apt-get install docker-compose-plugin"
    return 1
  fi

  log_error "Docker Compose 未安装"
  return 1
}

# ============================================================================
# 检测: 端口冲突
# ============================================================================
check_port_conflicts() {
  log_step "Checking port conflicts"

  local ports=(80 443 3000 3001 8080 8443)
  local conflicts=0

  for port in "${ports[@]}"; do
    if command -v ss &>/dev/null; then
      if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        log_warn "端口 $port 已被占用"
        ((conflicts++))
      fi
    elif command -v netstat &>/dev/null; then
      if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        log_warn "端口 $port 已被占用"
        ((conflicts++))
      fi
    fi
  done

  if [[ $conflicts -gt 0 ]]; then
    log_warn "$conflicts 个端口冲突，可能导致服务启动失败"
    read -p "是否继续? [y/N]: " confirm
    confirm="${confirm:-n}"
    [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]] && exit 1
  else
    log_info "所有必需端口可用"
  fi
}

# ============================================================================
# 检测: 磁盘空间
# ============================================================================
check_disk_space() {
  log_step "Checking disk space"

  local available
  available=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' || \
              df -k / 2>/dev/null | awk 'NR==2 {print $4}')

  local available_gb
  if [[ "$available" =~ ^-?[0-9]+$ ]]; then
    if [[ $available -lt 1024 ]]; then
      available_gb=$((available / 1024))
    else
      available_gb=$((available / 1024 / 1024))
    fi
  else
    available_gb=$((available / 1024 / 1024))
  fi

  log_info "可用磁盘空间: ${available}KB (约 ${available_gb}GB)"

  if [[ $available -lt 5242880 ]]; then  # < 5GB
    log_error "磁盘空间不足 (${available}KB < 5GB)，无法继续安装"
    return 1
  elif [[ $available -lt 20971520 ]]; then  # < 20GB
    log_warn "磁盘空间较低 (< 20GB)，建议清理后继续"
  fi
}

# ============================================================================
# 检测: 内存
# ============================================================================
check_memory() {
  log_step "Checking memory"

  local total_kb available_kb
  total_kb=$(free -k 2>/dev/null | awk 'NR==2 {print $2}' || echo 0)
  available_kb=$(free -k 2>/dev/null | awk 'NR==2 {print $7}' || echo 0)
  local total_gb=$((total_kb / 1024 / 1024))
  local available_gb=$((available_kb / 1024 / 1024))

  log_info "总内存: ${total_gb}GB, 可用: ${available_gb}GB"

  if [[ $total_kb -lt 2097152 ]]; then  # < 2GB
    log_error "内存不足 (${total_gb}GB < 2GB)，无法运行"
    return 1
  elif [[ $total_kb -lt 4194304 ]]; then  # < 4GB
    log_warn "内存较低 (< 4GB)，部分服务可能不稳定"
  fi
}

# ============================================================================
# 检测: 网络连通性
# ============================================================================
check_network_connectivity() {
  log_step "Checking network connectivity"

  local ok=0
  local slow=0
  local failed=0

  declare -A hosts=(
    ["hub.docker.com"]="Docker Hub"
    ["github.com"]="GitHub"
  )

  for host in "${!hosts[@]}"; do
    local name="${hosts[$host]}"
    local start end elapsed
    start=$(date +%s%N)
    if curl -sf --connect-timeout 5 --max-time 15 "https://${host}" &>/dev/null; then
      end=$(date +%s%N)
      elapsed=$(( (end - start) / 1000000 ))
      if [[ $elapsed -lt 1000 ]]; then
        log_info "[OK]   $name — ${elapsed}ms"
        ((ok++))
      else
        log_warn "[SLOW] $name — ${elapsed}ms"
        ((slow++))
      fi
    else
      log_error "[FAIL] $name"
      ((failed++))
    fi
  done

  if [[ $failed -gt 0 ]]; then
    log_warn "检测到 $failed 个网络问题，建议运行: ./scripts/setup-cn-mirrors.sh"
  fi
}

# ============================================================================
# 检测: 防火墙
# ============================================================================
check_firewall() {
  log_step "Checking firewall"

  if command -v ufw &>/dev/null; then
    local status
    status=$(sudo ufw status 2>/dev/null | head -1)
    if echo "$status" | grep -q "Status: active"; then
      log_warn "UFW 防火墙已启用，端口 80/443 可能需要放行"
      log_info "  运行: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
    fi
  fi

  if command -v firewall-cmd &>/dev/null; then
    local state
    state=$(sudo firewall-cmd --state 2>/dev/null || echo "unknown")
    if [[ "$state" == "running" ]]; then
      log_warn "Firewalld 运行中，请确保 80/443 端口开放"
    fi
  fi
}

# ============================================================================
# 网络检测 (原 check-deps.sh --network-check 功能)
# ============================================================================
check_cn_network() {
  if curl -sf --connect-timeout 5 --max-time 10 "https://www.baidu.com" &>/dev/null; then
    log_info "检测到中国大陆网络环境"
    log_info "建议运行: ./scripts/setup-cn-mirrors.sh 配置镜像加速"
    return 0
  fi
  log_info "未检测到中国大陆网络特征"
  return 1
}

# ============================================================================
# 主流程
# ============================================================================
main() {
  echo -e ""
  echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
  echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
  echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
  echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
  echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
  echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
  echo -e "${BOLD}                    S T A C K   v1.1.0${NC}"
  echo -e ""

  # 基础检查
  check_disk_space
  check_memory
  check_docker_install
  check_docker_permissions
  check_compose_v2
  check_port_conflicts
  check_network_connectivity
  check_firewall

  # CN 网络检测
  check_cn_network

  # 依赖检查
  log_step "Checking dependencies"
  bash "$SCRIPT_DIR/scripts/check-deps.sh"

  # 环境配置
  log_step "Environment configuration"
  if [[ ! -f .env ]]; then
    bash "$SCRIPT_DIR/scripts/setup-env.sh"
  else
    log_warn ".env already exists, skipping setup. Remove it to reconfigure."
  fi

  # 数据目录
  log_step "Creating data directories"
  mkdir -p \
    data/traefik/certs \
    data/portainer \
    data/prometheus \
    data/grafana \
    data/loki \
    data/authentik/media \
    data/nextcloud \
    data/gitea \
    data/vaultwarden

  chmod 600 config/traefik/acme.json 2>/dev/null || touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

  # 启动基础服务
  log_step "Launching base infrastructure"
  docker compose -f docker-compose.base.yml up -d

  log_info ""
  log_info "${GREEN}${BOLD}Base infrastructure is up!${NC}"
  log_info ""
  log_info "Next steps:"
  log_info "  ./scripts/stack-manager.sh start sso"
  log_info "  ./scripts/stack-manager.sh start monitoring"
  log_info "  ./scripts/stack-manager.sh list"
  log_info ""
  log_info "遇到问题? 运行: ./scripts/diagnose.sh"
}

main "$@"
