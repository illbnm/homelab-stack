#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — CN Mirror Setup
# 国内网络环境一键配置：Docker 镜像加速 + apt/pip 国内源
# 对应 Issue #8 [BOUNTY $250] Robustness — 国内网络适配
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[cn-mirrors]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cn-mirrors]${NC} $*"; }
log_error() { echo -e "${RED}[cn-mirrors]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}$*${NC}"; }

# ---------------------------------------------------------------------------
# 检测是否国内网络（通过 DNS/延迟判断，非强制）
# ---------------------------------------------------------------------------
is_cn_network() {
  local latency
  latency=$(curl -sf --connect-timeout 3 --max-time 5 -o /dev/null -w "%{time_total}" "https://www.baidu.com" 2>/dev/null || echo "999")
  # 百度可达且延迟 < 3s → 视为国内网络
  [[ "$latency" != "999" ]] && [[ "$(echo "$latency < 3" | bc -l 2>/dev/null || echo true)" == "true" ]]
}

# ---------------------------------------------------------------------------
# 1. Docker 镜像加速（daemon.json 配置）
# ---------------------------------------------------------------------------
setup_docker_mirror() {
  log_step "==> [1/4] 配置 Docker 镜像加速"
  local daemon_file="/etc/docker/daemon.json"
  local mirrors=(
    "https://docker.m.daocloud.io"
    "https://docker.1ms.run"
    "https://dockerproxy.com"
  )

  # 需要 root；若无 root 则提示（非致命）
  if [[ $EUID -ne 0 ]]; then
    log_warn "非 root，跳过 Docker daemon 全局配置（可用 cn-pull.sh 逐镜像加速）"
    return 0
  fi

  # 读取现有 daemon.json（若有）
  local existing="{}"
  if [[ -f "$daemon_file" ]]; then
    existing=$(cat "$daemon_file")
  fi

  # 合并 registry-mirrors（用 python 做 JSON 合并更稳）
  if command -v python3 &>/dev/null; then
    python3 - "$daemon_file" "$(IFS=,; echo "${mirrors[*]}")" <<'PYEOF'
import json, sys
daemon_file, mirrors_csv = sys.argv[1], sys.argv[2]
mirrors = [m.strip() for m in mirrors_csv.split(",") if m.strip()]
try:
    cfg = json.load(open(daemon_file)) if __import__('os').path.exists(daemon_file) else {}
except Exception:
    cfg = {}
cfg["registry-mirrors"] = mirrors
with open(daemon_file, "w") as f:
    json.dump(cfg, f, indent=2)
print(f"[cn-mirrors] daemon.json updated with {len(mirrors)} mirrors")
PYEOF
  else
    log_warn "无 python3，用简单方式写入 daemon.json"
    mkdir -p /etc/docker
    echo "{\"registry-mirrors\": [\"https://docker.m.daocloud.io\", \"https://docker.1ms.run\", \"https://dockerproxy.com\"]}" > "$daemon_file"
  fi

  # 重启 docker（若在运行）
  if command -v systemctl &>/dev/null && systemctl is-active docker &>/dev/null; then
    log_info "重启 Docker 使镜像加速生效..."
    systemctl restart docker 2>/dev/null || log_warn "docker 重启失败，需手动 systemctl restart docker"
  else
    log_warn "Docker 未运行或非 systemd，需手动重启 Docker 使配置生效"
  fi
}

# ---------------------------------------------------------------------------
# 2. apt 国内源（Debian/Ubuntu）
# ---------------------------------------------------------------------------
setup_apt_mirror() {
  log_step "==> [2/4] 配置 apt 国内源"
  if [[ ! -f /etc/os-release ]]; then
    log_warn "无 /etc/os-release，跳过 apt 源配置"
    return 0
  fi

  if ! grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
    log_warn "非 Debian/Ubuntu，跳过 apt 源配置"
    return 0
  fi

  if [[ $EUID -ne 0 ]]; then
    log_warn "非 root，跳过 apt 源配置（需 sudo）"
    return 0
  fi

  # 备份 + 替换为清华源
  cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s) 2>/dev/null || true
  if grep -qiE "ubuntu" /etc/os-release; then
    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-security main restricted universe multiverse
EOF
    log_info "已切换到清华 Ubuntu 源 ($codename)"
  else
    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ bookworm-security main contrib non-free
EOF
    log_info "已切换到清华 Debian 源 (bookworm)"
  fi
}

# ---------------------------------------------------------------------------
# 3. pip 国内源（全局配置）
# ---------------------------------------------------------------------------
setup_pip_mirror() {
  log_step "==> [3/4] 配置 pip 国内源"
  local pip_conf
  if [[ -d /etc ]]; then
    pip_conf="/etc/pip.conf"
  else
    pip_conf="$HOME/.config/pip/pip.conf"
    mkdir -p "$(dirname "$pip_conf")"
  fi
  cat > "$pip_conf" <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
  log_info "已配置 pip 清华源: $pip_conf"
}

# ---------------------------------------------------------------------------
# 4. npm 国内源（可选，提升 node 环境部署）
# ---------------------------------------------------------------------------
setup_npm_mirror() {
  log_step "==> [4/4] 配置 npm 国内源"
  if command -v npm &>/dev/null; then
    npm config set registry https://registry.npmmirror.com 2>/dev/null && log_info "已配置 npm 淘宝源" || log_warn "npm config 失败"
  else
    log_warn "无 npm，跳过"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_info "HomeLab Stack — 国内网络镜像配置"
log_info "检测国内网络: $(is_cn_network && echo '是 ✓' || echo '否（仍可手动执行）')"

setup_docker_mirror
setup_apt_mirror
setup_pip_mirror
setup_npm_mirror

log_info ""
log_info "✅ CN 镜像配置完成。Docker 需重启生效；apt 需 apt-get update；pip/npm 即时生效。"
log_info "   也可用 scripts/cn-pull.sh 对单个镜像做逐镜像加速拉取。"
