#!/usr/bin/env bash
# =============================================================================
# CN Mirror Setup — Docker 镜像加速配置工具
# 自动配置 Docker daemon.json 镜像加速源（中国大陆环境）
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP="${DAEMON_JSON}.backup.$(date +%Y%m%d%H%M%S)"

# 镜像源列表（按优先级排序）
PRIMARY_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://mirror.baidubce.com"
  "https://hub-mirror.c.163.com"
  "https://mirror.gcr.io"
)

FALLBACK_MIRRORS=(
  "https://dockerproxy.com"
  "https://docker.mirrors.ustc.edu.cn"
  "https://registry.docker-cn.com"
)

# 检测是否在中国大陆
detect_cn() {
  local ip country
  ip=$(curl -sf --connect-timeout 5 --max-time 10 "https://ipinfo.io/json" 2>/dev/null | grep -o '"country": *"[^"]*"' | cut -d'"' -f4 || true)
  if [[ "$ip" == "CN" ]]; then
    return 0
  fi
  # 备用检测
  if curl -sf --connect-timeout 3 --max-time 5 "https://myip.ipip.net" 2>/dev/null | grep -qi "中国"; then
    return 0
  fi
  return 1
}

# 测试镜像源可用性
test_mirror() {
  local mirror=$1
  curl -sf --connect-timeout 3 --max-time 5 "$mirror/v2/" &>/dev/null
}

# 选择可用镜像源
select_mirrors() {
  local available=()
  log_info "Testing mirror availability..."
  for mirror in "${PRIMARY_MIRRORS[@]}" "${FALLBACK_MIRRORS[@]}"; do
    if test_mirror "$mirror"; then
      log_info "  ✓ $mirror"
      available+=("$mirror")
    else
      log_warn "  ✗ $mirror (unreachable)"
    fi
  done

  if [[ ${#available[@]} -eq 0 ]]; then
    log_error "No mirrors reachable. Check your network."
    return 1
  fi
  echo "${available[@]}"
}

# 写入 daemon.json
write_config() {
  local mirrors=("$@")

  # 备份现有配置
  if [[ -f "$DAEMON_JSON" ]]; then
    cp "$DAEMON_JSON" "$BACKUP"
    log_info "Backed up existing config to $BACKUP"
  fi

  # 构建镜像源 JSON 数组
  local mirror_json
  mirror_json=$(printf '    "%s"\n' "${mirrors[@]}" | paste -sd ',' -)

  cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": [
${mirror_json}
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

  log_info "Written config to $DAEMON_JSON"
}

# 验证配置
verify() {
  log_info "Reloading Docker daemon..."
  if systemctl is-active --quiet docker 2>/dev/null; then
    systemctl reload docker 2>/dev/null || systemctl restart docker
    log_info "Docker daemon reloaded"
  fi

  log_info "Verifying with docker pull hello-world..."
  if docker pull hello-world &>/dev/null; then
    log_info "✓ Mirror configuration verified successfully!"
    return 0
  else
    log_warn "hello-world pull failed — mirrors may still work for other images"
    return 0
  fi
}

# 交互式模式
interactive() {
  echo -e "\n${BOLD}🇨🇳  Docker 镜像加速配置${NC}\n"

  if detect_cn; then
    log_info "Detected: You appear to be in mainland China (CN)"
  else
    log_info "Detected: You may not be in mainland China"
  fi

  echo ""
  read -rp "Are you in mainland China and need mirror acceleration? [Y/n]: " answer
  case "${answer:-Y}" in
    [Yy]*|"") ;;
    *) log_info "Skipping mirror configuration."; return 0 ;;
  esac

  echo ""
  read -rp "Auto-detect available mirrors? [Y/n]: " auto_answer
  local mirrors
  if [[ "${auto_answer:-Y}" =~ ^[Yy]*$ ]]; then
    mirrors=$(select_mirrors)
    if [[ -z "$mirrors" ]]; then
      log_error "Cannot proceed without available mirrors."
      return 1
    fi
  else
    echo "Available mirror options:"
    echo "  1) docker.m.daocloud.io (recommended)"
    echo "  2) mirror.baidubce.com"
    echo "  3) hub-mirror.c.163.com"
    echo "  4) mirror.gcr.io"
    echo "  5) All of the above"
    read -rp "Select [1-5, default 5]: " sel
    case "${sel:-5}" in
      1) mirrors=("https://docker.m.daocloud.io") ;;
      2) mirrors=("https://mirror.baidubce.com") ;;
      3) mirrors=("https://hub-mirror.c.163.com") ;;
      4) mirrors=("https://mirror.gcr.io") ;;
      5) mirrors=("https://docker.m.daocloud.io" "https://mirror.baidubce.com" "https://hub-mirror.c.163.com" "https://mirror.gcr.io") ;;
      *) log_error "Invalid selection"; return 1 ;;
    esac
  fi

  write_config "${mirrors[@]}"
  verify
}

usage() {
  echo "Usage: $0 [--auto | --check | --restore]"
  echo ""
  echo "  --auto     Auto-detect CN and configure mirrors (non-interactive)"
  echo "  --check    Test current mirror connectivity"
  echo "  --restore  Restore daemon.json from backup"
  echo "  (default)  Interactive setup"
}

case "${1:-}" in
  --auto)
    if detect_cn; then
      mirrors=$(select_mirrors)
      [[ -n "$mirrors" ]] && write_config $mirrors && verify
    else
      log_info "Not in CN region, skipping."
    fi
    ;;
  --check)
    select_mirrors || echo "No mirrors reachable"
    ;;
  --restore)
    latest=$(ls -t "${DAEMON_JSON}".backup.* 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
      cp "$latest" "$DAEMON_JSON"
      systemctl restart docker 2>/dev/null || true
      log_info "Restored from $latest"
    else
      log_error "No backup found"
      exit 1
    fi
    ;;
  -h|--help) usage ;;
  *) interactive ;;
esac
