#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# 增强版：支持中国大陆网络环境自动适配
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
LOG_FILE="${HOME}/.homelab/install.log"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "安装失败。查看日志: $LOG_FILE"
    log_info "运行诊断: ./scripts/diagnose.sh"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# curl_retry — 带重试的 curl（指数退避）
# ---------------------------------------------------------------------------
curl_retry() {
  local max_attempts="${CURL_MAX_ATTEMPTS:-3}"
  local timeout="${CURL_TIMEOUT:-30}"
  local attempt=1

  while ((attempt <= max_attempts)); do
    if curl -sfL --connect-timeout 10 --max-time "$timeout" "$@" &>> "$LOG_FILE"; then
      return 0
    fi

    if ((attempt < max_attempts)); then
      local wait_time=$((2 ** attempt))
      log_warn "curl 失败（第 ${attempt}/${max_attempts} 次），${wait_time}秒后重试..."
      sleep "$wait_time"
    fi
    ((attempt++)) || true
  done

  log_error "curl 重试 ${max_attempts} 次后仍失败"
  return 1
}

# ---------------------------------------------------------------------------
# 检测 Docker 是否安装
# ---------------------------------------------------------------------------
ensure_docker() {
  log_step "检查 Docker"

  if ! command -v docker &>/dev/null; then
    log_warn "Docker 未安装，正在尝试安装..."

    if [[ -f /etc/debian_version ]]; then
      # Debian/Ubuntu
      log_info "检测到 Debian/Ubuntu 系统"
      export DEBIAN_FRONTEND=noninteractive

      # 添加 Docker GPG 密钥和仓库
      curl_retry -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>> "$LOG_FILE"
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

      apt-get update -qq
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>> "$LOG_FILE"

    elif [[ -f /etc/redhat-release ]]; then
      # RHEL/CentOS/Fedora
      log_info "检测到 RHEL/CentOS/Fedora 系统"
      yum install -y yum-utils 2>> "$LOG_FILE"
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>> "$LOG_FILE"
      yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>> "$LOG_FILE"

    else
      log_error "不支持的操作系统。请手动安装 Docker: https://docs.docker.com/get-docker/"
      exit 1
    fi

    # 启动 Docker
    if command -v systemctl &>/dev/null; then
      systemctl start docker || service docker start 2>/dev/null || true
      systemctl enable docker || true
    fi

    # 添加当前用户到 docker 组
    if [[ -n "${SUDO_USER:-}" ]]; then
      usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    elif [[ -n "$USER" && "$USER" != "root" ]]; then
      usermod -aG docker "$USER" 2>/dev/null || true
    fi

    log_info "Docker 安装完成"
  fi

  # 等待 Docker 就绪
  local wait_count=0
  while ! docker info &>/dev/null; do
    sleep 1
    ((wait_count++)) || true
    if [[ $wait_count -ge 30 ]]; then
      log_error "Docker 服务启动超时"
      log_info "请手动启动 Docker: sudo systemctl start docker"
      exit 1
    fi
  done

  log_info "Docker 已就绪: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
}

# ---------------------------------------------------------------------------
# 检测 Docker Compose 版本
# ---------------------------------------------------------------------------
check_compose_version() {
  log_step "检查 Docker Compose"

  if docker compose version &>/dev/null; then
    local ver
    ver=$(docker compose version --short 2>/dev/null)
    log_info "Docker Compose v2: $ver"

    # 检查是否是 v2 (plugin)
    if ! docker compose version 2>&1 | grep -q "v2"; then
      log_warn "检测到 Docker Compose v1，请升级到 v2"
      log_info "升级指南: https://docs.docker.com/compose/migrate/"
    fi
  elif command -v docker-compose &>/dev/null; then
    local ver
    ver=$(docker-compose --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    log_warn "Docker Compose v1 ($ver) 已安装"
    log_warn "建议升级到 Docker Compose v2 (Docker Desktop 或独立安装)"
    log_info "升级指南: https://docs.docker.com/compose/migrate/"
    log_info "继续安装（v1 仍可正常工作）..."
  else
    log_error "Docker Compose 未安装"
    log_info "Docker Desktop 已包含 Compose v2，或运行: apt install docker-compose-plugin"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# 检测端口冲突
# ---------------------------------------------------------------------------
check_port_conflicts() {
  log_step "检查端口冲突"

  local ports=(
    "53:DNS"
    "80:HTTP"
    "443:HTTPS"
    "3000:Dashboard"
    "8080:Traefik"
    "9000:Portainer"
    "2375:Docker Socket Proxy"
  )

  local conflicts=()
  for entry in "${ports[@]}"; do
    local port="${entry%%:*}"
    local name="${entry#*:}"

    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      conflicts+=("$port ($name)")
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    log_warn "以下端口已被占用:"
    for c in "${conflicts[@]}"; do
      echo "  - $c"
    done
    echo ""
    log_warn "相关服务可能无法启动。请释放端口或修改配置。"
    echo ""
    read -r -p "是否继续安装？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log_info "安装已取消"
      exit 0
    fi
  else
    log_info "所有必需端口可用"
  fi
}

# ---------------------------------------------------------------------------
# 网络环境检测（中国大陆适配）
# ---------------------------------------------------------------------------
detect_cn_network() {
  log_step "网络环境检测"

  # 检测方法1：能否直连 Docker Hub
  if curl -sf --connect-timeout 5 --max-time 10 "https://registry-1.docker.io/v2/" &>/dev/null; then
    log_info "网络环境: 海外（直连 Docker Hub）"
    return 1
  fi

  # 检测方法2：能否访问国内站点
  if curl -sf --connect-timeout 5 --max-time 10 "https://www.baidu.com" &>/dev/null; then
    log_info "网络环境: 中国大陆"
    return 0
  fi

  # 兜底
  log_warn "无法确定网络环境，继续安装..."
  return 1
}

# ---------------------------------------------------------------------------
# 配置 apt/pip 镜像源
# ---------------------------------------------------------------------------
configure_package_mirrors() {
  local is_cn=$1

  if [[ "$is_cn" != "0" ]]; then
    return
  fi

  log_step "配置国内软件源"

  # apt 镜像源（Ubuntu/Debian）
  if [[ -f /etc/apt/sources.list ]]; then
    if grep -q "archive.ubuntu.com" /etc/apt/sources.list 2>/dev/null; then
      log_info "配置清华 apt 源..."
      cat > /etc/apt/sources.list <<'APTEOF'
# 清华镜像源（适用于 Ubuntu 22.04）
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
APTEOF
      apt-get update -qq 2>> "$LOG_FILE" || true
      log_info "apt 源配置完成"
    fi
  fi

  # pip 镜像源
  if command -v pip3 &>/dev/null; then
    log_info "配置 pip 清华源..."
    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || \
    mkdir -p ~/.config/pip 2>/dev/null && \
    echo "[global]" > ~/.config/pip/pip.conf && \
    echo "index-url = https://pypi.tuna.tsinghua.edu.cn/simple" >> ~/.config/pip/pip.conf || true
    log_info "pip 源配置完成"
  fi

  # Alpine 镜像源（如果存在 /etc/apk/repositories）
  if [[ -f /etc/alpine-release ]]; then
    log_info "配置 Alpine 中科大源..."
    cat > /etc/apk/repositories <<'APKEOF'
https://mirrors.ustc.edu.cn/alpine/v3.18/main
https://mirrors.ustc.edu.cn/alpine/v3.18/community
APKEOF
    log_info "Alpine 源配置完成"
  fi
}

# ---------------------------------------------------------------------------
# 镜像拉取（带 CN 适配）
# ---------------------------------------------------------------------------
pull_images_with_cn_support() {
  local is_cn=$1
  local compose_file="${2:-}"

  if [[ "$is_cn" != "0" ]]; then
    # 海外环境，直接拉取
    log_info "正在拉取 Docker 镜像..."
    if [[ -n "$compose_file" ]]; then
      docker compose -f "$compose_file" pull 2>> "$LOG_FILE" || true
    fi
    return
  fi

  # 中国大陆环境
  log_info "检测到中国大陆网络环境，尝试配置镜像加速..."

  # 检查并配置镜像源
  if [[ -x "${SCRIPTS_DIR}/setup-cn-mirrors.sh" ]]; then
    bash "${SCRIPTS_DIR}/setup-cn-mirrors.sh" --silent 2>&1 | tee -a "$LOG_FILE" || true
  fi

  # 检查镜像映射
  if [[ -x "${SCRIPTS_DIR}/localize-images.sh" ]]; then
    log_info "应用镜像源映射..."
    bash "${SCRIPTS_DIR}/localize-images.sh" --cn 2>&1 | tee -a "$LOG_FILE" || true
  fi

  log_info "镜像配置完成"
}

# ---------------------------------------------------------------------------
# 创建目录结构
# ---------------------------------------------------------------------------
create_directories() {
  log_step "创建数据目录"

  mkdir -p \
    "${SCRIPT_DIR}/data/traefik/certs" \
    "${SCRIPT_DIR}/data/portainer" \
    "${SCRIPT_DIR}/data/prometheus" \
    "${SCRIPT_DIR}/data/grafana" \
    "${SCRIPT_DIR}/data/loki" \
    "${SCRIPT_DIR}/data/authentik/media" \
    "${SCRIPT_DIR}/data/nextcloud" \
    "${SCRIPT_DIR}/data/gitea" \
    "${SCRIPT_DIR}/data/vaultwarden" \
    "${SCRIPT_DIR}/data/nginx-proxy-manager" \
    "${SCRIPT_DIR}/data/adguard" \
    "${SCRIPT_DIR}/data/jellyfin" \
    "${SCRIPT_DIR}/data/gitea" \
    "${SCRIPT_DIR}/data/outline" \
    "${SCRIPT_DIR}/data/minio"

  # Traefik ACME 证书文件
  local acme_path="${SCRIPT_DIR}/config/traefik/acme.json"
  if [[ ! -f "$acme_path" ]]; then
    touch "$acme_path"
  fi
  chmod 600 "$acme_path" 2>/dev/null || true

  log_info "目录结构已创建"
}

# ---------------------------------------------------------------------------
# 启动基础服务
# ---------------------------------------------------------------------------
start_base_infrastructure() {
  log_step "启动基础服务"

  local compose_file="${SCRIPT_DIR}/stacks/base/docker-compose.yml"

  if [[ ! -f "$compose_file" ]]; then
    log_warn "未找到基础 compose 文件: $compose_file"
    log_info "跳过基础服务启动"
    return
  fi

  # 创建 proxy 网络
  if ! docker network inspect proxy &>/dev/null; then
    log_info "创建 docker network: proxy"
    docker network create proxy 2>> "$LOG_FILE" || true
  fi

  # 拉取镜像（带 CN 适配）
  local is_cn=1
  detect_cn_network && is_cn=0
  pull_images_with_cn_support "$is_cn" "$compose_file"

  # 启动服务
  log_info "启动基础服务..."
  cd "$(dirname "$compose_file")"
  if docker compose -f "$(basename "$compose_file")" up -d 2>> "$LOG_FILE"; then
    log_info "基础服务已启动"

    # 等待健康检查
    if [[ -x "${SCRIPTS_DIR}/wait-healthy.sh" ]]; then
      log_info "等待容器健康检查..."
      bash "${SCRIPTS_DIR}/wait-healthy.sh" "$(basename "$compose_file")" -t 300 2>&1 | tee -a "$LOG_FILE" || log_warn "部分容器可能未通过健康检查"
    fi
  else
    log_error "基础服务启动失败"
    log_info "查看日志: $LOG_FILE"
    log_info "运行诊断: ./scripts/diagnose.sh"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
banner() {
  echo -e ""
  echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
  echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
  echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
  echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
  echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
  echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
  echo -e "${BOLD}                    S T A C K   v1.1.0${NC}"
  echo -e ""
  echo -e "${BLUE}  🚀 增强版安装程序 — 支持中国大陆网络自动适配${NC}"
  echo -e ""
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
main() {
  # 记录日志
  echo "=== 安装开始: $(date) ===" >> "$LOG_FILE"

  banner

  # Step 1: Docker 检测/安装
  ensure_docker

  # Step 2: Docker Compose 版本检测
  check_compose_version

  # Step 3: 端口冲突检测
  check_port_conflicts

  # Step 4: 网络环境检测
  local is_cn=1
  detect_cn_network && is_cn=0

  # Step 5: 配置包管理器镜像源
  configure_package_mirrors "$is_cn"

  # Step 6: 配置环境
  log_step "环境配置"
  if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
    if [[ -x "${SCRIPTS_DIR}/setup-env.sh" ]]; then
      bash "${SCRIPTS_DIR}/setup-env.sh"
    else
      log_error "setup-env.sh 不存在"
      exit 1
    fi
  else
    log_warn ".env 已存在，跳过环境配置。删除它以重新配置。"
  fi

  # Step 7: 创建目录
  create_directories

  # Step 8: 启动基础服务
  start_base_infrastructure

  echo ""
  echo -e "${GREEN}${BOLD}✓ 安装完成！${NC}"
  echo ""
  log_info "详细日志: $LOG_FILE"
  echo ""
  echo "常用命令:"
  echo "  ./scripts/stack-manager.sh list      # 查看可用堆栈"
  echo "  ./scripts/stack-manager.sh start sso # 启动 SSO"
  echo "  ./scripts/diagnose.sh                # 运行诊断"
  echo "  ./scripts/check-connectivity.sh      # 检测网络"
  echo ""
  echo "文档: docs/getting-started.md"

  echo "=== 安装完成: $(date) ===" >> "$LOG_FILE"
}

main "$@"
