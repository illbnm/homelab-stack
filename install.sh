#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer (增强鲁棒性版本)
# 支持自动安装 Docker、网络检测、端口冲突检查等
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>$NC $*"; }

# 日志文件
LOG_DIR="$HOME/.homelab"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"

# 清理函数
cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "安装失败。详细日志：$LOG_FILE"
  fi
}
trap cleanup EXIT

# 记录日志
log_to_file() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# =============================================================================
# 网络工具函数
# =============================================================================

# 带重试的 curl 包装函数
curl_retry() {
  local max_attempts=3
  local delay=5
  local url="$1"
  shift
  
  for i in $(seq 1 $max_attempts); do
    if curl --connect-timeout 10 --max-time 60 "$url" "$@"; then
      return 0
    fi
    log_warn "Attempt $i failed, retrying in ${delay}s..."
    log_to_file "CURL retry $i: $url"
    sleep $delay
    delay=$((delay * 2))
  done
  
  log_error "CURL failed after $max_attempts attempts: $url"
  return 1
}

# 检测是否在中国大陆
is_cn_network() {
  log_step "检测网络环境"
  
  # 测试 GitHub 访问
  local start_time=$(date +%s%N)
  if curl -sf --connect-timeout 3 --max-time 5 "https://github.com" &>/dev/null; then
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $latency -gt 500 ]]; then
      log_warn "GitHub 访问延迟 ${latency}ms，建议开启镜像加速"
      return 0
    fi
  else
    log_warn "GitHub 访问超时，可能在国内网络环境"
    return 0
  fi
  
  # 测试 gcr.io
  if ! curl -sf --connect-timeout 3 "https://gcr.io" &>/dev/null; then
    log_warn "gcr.io 无法访问，需要使用国内镜像"
    return 0
  fi
  
  return 1
}

# =============================================================================
# Docker 安装函数
# =============================================================================

# 检测操作系统
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif command -v apt-get &>/dev/null; then
    echo "debian"
  elif command -v yum &>/dev/null; then
    echo "centos"
  elif command -v pacman &>/dev/null; then
    echo "arch"
  else
    echo "unknown"
  fi
}

# 安装 Docker (Ubuntu/Debian)
install_docker_ubuntu() {
  log_step "安装 Docker (Ubuntu/Debian)"
  
  # 卸载旧版本
  sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
  
  # 更新包索引
  sudo apt-get update
  
  # 安装依赖
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  
  # 添加 GPG 密钥
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  
  # 添加仓库
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # 安装 Docker
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # 启动 Docker
  sudo systemctl enable docker
  sudo systemctl start docker
  
  log_info "Docker 安装完成"
}

# 安装 Docker (CentOS/RHEL)
install_docker_centos() {
  log_step "安装 Docker (CentOS/RHEL)"
  
  # 卸载旧版本
  sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
  
  # 安装 yum-utils
  sudo yum install -y yum-utils
  
  # 添加仓库
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  
  # 安装 Docker
  sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # 启动 Docker
  sudo systemctl enable docker
  sudo systemctl start docker
  
  log_info "Docker 安装完成"
}

# 安装 Docker (Arch Linux)
install_docker_arch() {
  log_step "安装 Docker (Arch Linux)"
  
  sudo pacman -Sy --noconfirm docker docker-compose
  
  # 启动 Docker
  sudo systemctl enable docker
  sudo systemctl start docker
  
  log_info "Docker 安装完成"
}

# 检查并安装 Docker
check_and_install_docker() {
  log_step "检查 Docker 安装状态"
  
  if ! command -v docker &>/dev/null; then
    log_warn "Docker 未安装，开始自动安装..."
    
    local os=$(detect_os)
    log_info "检测到操作系统：$os"
    
    case "$os" in
      ubuntu|debian)
        install_docker_ubuntu
        ;;
      centos|rhel|fedora)
        install_docker_centos
        ;;
      arch|manjaro)
        install_docker_arch
        ;;
      *)
        log_error "不支持的操作系统：$os"
        log_info "请手动安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
        ;;
    esac
  else
    local version=$(docker --version)
    log_info "Docker 已安装：$version"
    
    # 检查版本 (>= 24.0)
    local major_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d. -f1 || echo "0")
    if [[ "$major_version" -lt 24 ]]; then
      log_warn "Docker 版本过旧 ($major_version)，建议升级到 >= 24.0"
    fi
  fi
  
  # 检查 Docker 服务
  if ! docker info &>/dev/null; then
    log_error "Docker 服务未运行"
    log_info "尝试启动 Docker 服务..."
    
    if systemctl is-active --quiet docker; then
      sudo systemctl start docker
    elif service docker status &>/dev/null; then
      sudo service docker start
    else
      log_error "无法启动 Docker 服务"
      exit 1
    fi
  fi
  
  log_info "Docker 服务运行正常"
}

# 检查 Docker Compose
check_compose() {
  log_step "检查 Docker Compose"
  
  if docker compose version &>/dev/null; then
    local version=$(docker compose version --short 2>/dev/null || echo "unknown")
    log_info "Docker Compose v2 已安装：$version"
  elif command -v docker-compose &>/dev/null; then
    local version=$(docker-compose --version 2>&1 | head -1)
    log_warn "检测到 Docker Compose v1: $version"
    log_info "建议升级到 Docker Compose v2 插件"
    log_info "  https://docs.docker.com/compose/migrate/"
  else
    log_warn "Docker Compose 未安装"
    log_info "Docker Compose v2 通常随 Docker 一起安装"
  fi
}

# =============================================================================
# 端口冲突检测
# =============================================================================

check_port_conflicts() {
  log_step "检测端口冲突"
  
  local ports=(53 80 443 3000 8080 8443 9000)
  local conflicts=0
  
  for port in "${ports[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      local process=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 | awk '{print $7}' || \
                     netstat -tlnp 2>/dev/null | grep ":${port} " | head -1 | awk '{print $7}' || \
                     echo "unknown")
      log_warn "端口 $port 被占用: $process"
      ((conflicts++))
    else
      log_info "端口 $port 可用"
    fi
  done
  
  if [[ $conflicts -gt 0 ]]; then
    log_warn "发现 $conflicts 个端口冲突"
    log_info "如需继续，请先停止占用端口的服务或修改配置"
  fi
}

# =============================================================================
# 磁盘空间检查
# =============================================================================

check_disk_space() {
  log_step "检查磁盘空间"
  
  local free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  local required_gb=10
  
  if [[ "$free_gb" -ge "$required_gb" ]]; then
    log_info "磁盘空间充足：${free_gb}GB 可用"
  else
    log_warn "磁盘空间不足：${free_gb}GB 可用 (推荐 >= ${required_gb}GB)"
    log_info "HomeLab Stack 建议至少 10GB 可用空间"
  fi
}

# =============================================================================
# 环境配置
# =============================================================================

setup_environment() {
  log_step "配置环境变量"
  
  if [[ ! -f .env ]]; then
    log_info "创建 .env 文件"
    cp .env.example .env 2>/dev/null || true
    bash "$(dirname "$0")/scripts/setup-env.sh"
  else
    log_info ".env 文件已存在"
  fi
}

# =============================================================================
# 创建目录
# =============================================================================

create_directories() {
  log_step "创建数据目录"
  
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
  
  # 设置 acme.json 权限
  chmod 600 config/traefik/acme.json 2>/dev/null || \
    (touch config/traefik/acme.json && chmod 600 config/traefik/acme.json)
  
  log_info "目录创建完成"
}

# =============================================================================
# 主安装流程
# =============================================================================

main() {
  echo -e ""
  echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
  echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
  echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
  echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
  echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
  echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
  echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
  echo -e ""
  
  log_to_file "Installation started"
  
  # Step 1: 检查/安装 Docker
  check_and_install_docker
  
  # Step 2: 检查 Docker Compose
  check_compose
  
  # Step 3: 网络环境检测
  if is_cn_network; then
    log_warn "检测到国内网络环境"
    log_info "建议运行以下命令配置镜像加速:"
    log_info "  sudo ./scripts/setup-cn-mirrors.sh --auto"
    log_info "  ./scripts/localize-images.sh --cn"
    
    read -p "是否现在配置镜像加速？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      sudo bash "$(dirname "$0")/scripts/setup-cn-mirrors.sh --auto"
    fi
  fi
  
  # Step 4: 端口冲突检测
  check_port_conflicts
  
  # Step 5: 磁盘空间检查
  check_disk_space
  
  # Step 6: 环境配置
  setup_environment
  
  # Step 7: 创建目录
  create_directories
  
  # Step 8: 启动基础服务
  log_step "启动基础服务"
  docker compose -f docker-compose.base.yml up -d
  
  log_to_file "Installation completed successfully"
  
  echo -e ""
  log_info "${GREEN}${BOLD}✓ 基础服务已启动!${NC}"
  echo -e ""
  log_info "下一步操作:"
  log_info "  ./scripts/stack-manager.sh start sso        # 设置 SSO (推荐)"
  log_info "  ./scripts/stack-manager.sh start monitoring # 启动监控"
  log_info "  ./scripts/stack-manager.sh list             # 查看所有 Stack"
  log_info ""
  log_info "文档：docs/getting-started.md"
  log_info "日志：$LOG_FILE"
  echo -e ""
}

main "$@"
