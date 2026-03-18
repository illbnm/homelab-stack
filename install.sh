#!/usr/bin/env bash
# =============================================================================
# install.sh — HomeLab Stack 一键安装
# 支持 Ubuntu/Debian/CentOS/Arch，自动处理依赖和环境
# =============================================================================

set -euo pipefail

log()  { echo "[install] $*"; }
ok()   { echo "[install] ✅ $*"; }
fail() { echo "[install] ❌ $*"; exit 1; }
warn() { echo "[install] ⚠️  $*"; }

curl_retry() {
  local max_attempts=3 delay=5
  for i in $(seq 1 $max_attempts); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    echo "  Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}

# ── System Detection ─────────────────────────────────────────────────────────

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
  else
    fail "无法检测操作系统"
  fi
  log "检测到: ${OS} ${OS_VERSION}"
}

# ── Docker Installation ──────────────────────────────────────────────────────

install_docker() {
  if command -v docker &>/dev/null; then
    local ver=$(docker --version | grep -oP '\d+\.\d+\.\d+')
    ok "Docker 已安装 (${ver})"
    return 0
  fi

  log "安装 Docker..."
  case "$OS" in
    ubuntu|debian)
      apt-get update -qq
      apt-get install -y -qq ca-certificates curl gnupg
      curl_retry -fsSL https://get.docker.com | sh
      ;;
    centos|rhel|fedora)
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      systemctl enable --now docker
      ;;
    arch|manjaro)
      pacman -Sy --noconfirm docker docker-compose
      systemctl enable --now docker
      ;;
    *)
      warn "未知系统 ${OS}，尝试通用安装..."
      curl_retry -fsSL https://get.docker.com | sh
      ;;
  esac

  usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
  ok "Docker 安装完成"
}

# ── Docker Compose Check ─────────────────────────────────────────────────────

check_compose() {
  if docker compose version &>/dev/null; then
    local ver=$(docker compose version --short 2>/dev/null || echo "v2+")
    ok "Docker Compose ${ver}"
    return 0
  fi

  if command -v docker-compose &>/dev/null; then
    local ver=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+')
    warn "检测到 Docker Compose v1 (${ver})"
    warn "建议升级到 v2: https://docs.docker.com/compose/install/"
    warn "本项目使用 'docker compose' (v2) 命令"
    return 0
  fi

  fail "Docker Compose 未安装"
}

# ── Port Conflict Check ──────────────────────────────────────────────────────

check_ports() {
  log "检测端口冲突..."
  local conflicts=0
  for port in 53 80 443 3000 8080 9090; do
    if ss -tlnp | grep -q ":${port} "; then
      local proc=$(ss -tlnp | grep ":${port} " | awk '{print $NF}' | head -1)
      warn "端口 ${port} 已被占用: ${proc}"
      ((conflicts++))
    fi
  done

  if [[ $conflicts -eq 0 ]]; then
    ok "无端口冲突"
  else
    warn "${conflicts} 个端口冲突，部分服务可能需要调整"
  fi
}

# ── Disk Space Check ─────────────────────────────────────────────────────────

check_disk() {
  local avail=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
  if [[ $avail -lt 20 ]]; then
    warn "磁盘空间不足: ${avail}GB 可用 (建议 ≥ 20GB)"
  else
    ok "磁盘空间: ${avail}GB 可用"
  fi
}

# ── Network Setup ────────────────────────────────────────────────────────────

setup_networks() {
  log "创建 Docker 网络..."
  docker network create proxy 2>/dev/null && ok "网络: proxy" || log "网络 proxy 已存在"
  docker network create internal 2>/dev/null && ok "网络: internal" || log "网络 internal 已存在"
}

# ── Environment File ─────────────────────────────────────────────────────────

setup_env() {
  if [[ -f .env ]]; then
    ok ".env 文件已存在"
    return 0
  fi

  if [[ -f .env.example ]]; then
    cp .env.example .env
    ok "已从 .env.example 创建 .env"
    warn "请编辑 .env 填写密码和域名"
  else
    warn "未找到 .env.example，请手动创建 .env"
  fi
}

# ── CN Mirror Check ──────────────────────────────────────────────────────────

check_cn() {
  if [[ -x "./scripts/check-connectivity.sh" ]]; then
    log "检测网络连通性..."
    bash ./scripts/check-connectivity.sh 2>/dev/null || true
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo "=============================================="
echo "  HomeLab Stack 安装程序"
echo "=============================================="
echo ""

detect_os
install_docker
check_compose
check_ports
check_disk
setup_networks
setup_env
check_cn

echo ""
echo "=============================================="
echo "  安装完成！"
echo ""
echo "  下一步:"
echo "  1. 编辑 .env 配置域名和密码"
echo "  2. docker compose -f stacks/base/docker-compose.yml up -d"
echo "  3. docker compose -f stacks/databases/docker-compose.yml up -d"
echo "  4. 按需启动其他 stack"
echo "=============================================="
