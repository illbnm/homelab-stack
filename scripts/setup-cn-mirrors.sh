#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Docker 镜像加速器 + 国内源配置
# 支持交互式和静默模式，自动写入 /etc/docker/daemon.json
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[setup-cn]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[setup-cn]${NC} $*"; }
log_error() { echo -e "${RED}[setup-cn]${NC} $*" >&2; }
log_ok()    { echo -e "${GREEN}[setup-cn]${NC} ${BOLD}✓${NC} $*"; }

DRY_RUN=false
INTERACTIVE=true
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_JSON="/etc/docker/daemon.json.bak"

# 可用镜像源
MIRROR_SOURCES=(
  "m.daocloud.io"
  "docker.m.daocloud.io"
  "hub-mirror.c.163.com"
  "mirror.baidubce.com"
  "dockerproxy.cn"
)

usage() {
  cat << EOF
用法: $0 [选项]

配置 Docker 镜像加速器（主要用于中国大陆网络环境）

选项:
  --dry-run       预览配置，不实际写入
  --non-interactive  静默模式，使用默认配置
  --restore       恢复原始 daemon.json（撤销之前的配置）
  --check         检查当前配置状态
  -h, --help      显示帮助

示例:
  $0                      # 交互式配置
  $0 --dry-run           # 预览配置
  $0 --non-interactive   # 静默使用默认配置
  $0 --restore           # 恢复原始配置
EOF
}

# 解析参数
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true; INTERACTIVE=false ;;
    --non-interactive) INTERACTIVE=false ;;
    --restore) RESTORE=true ;;
    --check) CHECK=true ;;
    -h|--help) usage; exit 0 ;;
  esac
done

RESTORE=${RESTORE:-false}
CHECK=${CHECK:-false}

# 检测是否在中国大陆
detect_cn_network() {
  local latency
  latency=$(curl -sf --connect-timeout 3 --max-time 5 \
    -o /dev/null -w '%{time_total}' \
    "https://hub.docker.com/v2/" 2>/dev/null || echo "999")

  if [[ "$(echo "$latency < 2.0" | bc -l 2>/dev/null || echo 0)" == "1" ]]; then
    return 1  # 不在中国，网络正常
  fi

  # 检测 gcr.io/ghcr.io 是否可达
  if ! curl -sf --connect-timeout 3 --max-time 5 \
    "https://gcr.io" >/dev/null 2>&1; then
    return 0  # gcr.io 不可达，在中国
  fi
  return 1
}

# 获取系统信息
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif command -v apt-get &>/dev/null; then
    echo "debian"
  elif command -v yum &>/dev/null; then
    echo "rhel"
  else
    echo "unknown"
  fi
}

# 备份现有配置
backup_daemon_json() {
  if [[ -f "$DAEMON_JSON" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "[dry-run] Would backup $DAEMON_JSON → $BACKUP_JSON"
    else
      cp "$DAEMON_JSON" "$BACKUP_JSON"
      log_info "Backed up existing $DAEMON_JSON → $BACKUP_JSON"
    fi
  fi
}

# 读取现有 daemon.json
read_existing_config() {
  if [[ -f "$DAEMON_JSON" ]]; then
    python3 -c "import json; print(json.dumps(json.load(open('$DAEMON_JSON')), indent=2))" 2>/dev/null || cat "$DAEMON_JSON"
  else
    echo "{}"
  fi
}

# 合并镜像源（避免重复）
merge_mirrors() {
  local new_mirrors=("$@")
  local existing=""
  local all_mirrors=()

  if [[ -f "$DAEMON_JSON" ]]; then
    existing=$(python3 -c "
import json, sys
d = json.load(open('$DAEMON_JSON'))
print(' '.join(d.get('registry-mirrors', [])))
" 2>/dev/null || true)
  fi

  while IFS read -r m; do
    [[ -z "$m" ]] && continue
    # 去重
    local dup=false
    for existing_m in $existing; do
      [[ "$m" == "$existing_m" ]] && dup=true && break
    done
    [[ "$dup" == "false" ]] && all_mirrors+=("$m")
  done <<< "$existing"

  for m in "${new_mirrors[@]}"; do
    local dup=false
    for existing_m in $existing; do
      [[ "$m" == "$existing_m" ]] && dup=true && break
    done
    [[ "$dup" == "false" ]] && all_mirrors+=("$m")
  done

  printf '%s\n' "${all_mirrors[@]}"
}

# 生成 daemon.json
generate_daemon_json() {
  local mirrors=("$@")
  python3 - << PYEOF
import json, sys

existing = {}
try:
    with open('$DAEMON_JSON') as f:
        existing = json.load(f)
except:
    pass

new_mirrors = ${mirrors:-$([ -t 0 ] && echo '[]' || echo '[]')}

# Get existing mirrors
existing_mirrors = existing.get('registry-mirrors', [])
# Add new ones without duplicates
seen = set(existing_mirrors)
for m in new_mirrors:
    if m not in seen:
        existing_mirrors.append(m)
        seen.add(m)

if existing_mirrors:
    existing['registry-mirrors'] = existing_mirrors

# Write with proper formatting
output = json.dumps(existing, indent=2, ensure_ascii=False)
print(output)
PYEOF
}

# 验证镜像加速配置
verify_config() {
  log_info "Verifying Docker configuration..."

  if ! command -v docker &>/dev/null; then
    log_error "Docker not installed. Please install Docker first."
    return 1
  fi

  if [[ ! -r "$DAEMON_JSON" ]]; then
    log_error "$DAEMON_JSON not found or not readable"
    return 1
  fi

  # Validate JSON
  if ! python3 -c "import json; json.load(open('$DAEMON_JSON'))" 2>/dev/null; then
    log_error "$DAEMON_JSON is not valid JSON"
    return 1
  fi

  # Check registry-mirrors
  local mirrors
  mirrors=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(' '.join(d.get('registry-mirrors',[])))" 2>/dev/null)
  if [[ -z "$mirrors" ]]; then
    log_warn "No registry-mirrors configured in $DAEMON_JSON"
    return 1
  fi

  log_ok "registry-mirrors configured: $mirrors"

  # Test pull speed
  log_info "Testing mirror speed with hello-world..."
  local start_time
  start_time=$(date +%s)

  if docker pull "$(
    python3 -c "import json; print(json.load(open('$DAEMON_JSON'))['registry-mirrors'][0])" 2>/dev/null || echo ''
  )/library/hello-world:latest" 2>/dev/null; then
    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    log_ok "Docker pull via mirror succeeded in ${elapsed}s"
    return 0
  else
    log_warn "Docker pull via mirror failed — trying direct"
    if docker pull hello-world:latest 2>/dev/null; then
      log_ok "Direct pull succeeded"
      return 0
    fi
    return 1
  fi
}

# 主流程
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║     HomeLab Stack — Docker 镜像加速器配置              ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Check mode
  if [[ "$CHECK" == "true" ]]; then
    log_info "Checking current Docker configuration..."
    if [[ -f "$DAEMON_JSON" ]]; then
      echo -e "${BLUE}Current $DAEMON_JSON:${NC}"
      cat "$DAEMON_JSON"
      echo ""
    else
      log_info "No custom Docker configuration found."
    fi
    local mirrors
    mirrors=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(' '.join(d.get('registry-mirrors',[])))" 2>/dev/null || echo "")
    if [[ -n "$mirrors" ]]; then
      log_ok "Mirror sources configured: $mirrors"
    else
      log_warn "No mirror sources configured."
    fi
    exit 0
  fi

  if [[ "$RESTORE" == "true" ]]; then
    if [[ -f "$BACKUP_JSON" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would restore $BACKUP_JSON → $DAEMON_JSON"
      else
        cp "$BACKUP_JSON" "$DAEMON_JSON"
        log_ok "Restored $DAEMON_JSON from backup"
        log_info "Run 'sudo systemctl restart docker' to apply changes"
      fi
    else
      log_error "No backup found at $BACKUP_JSON"
      exit 1
    fi
    exit 0
  fi

  # Check root
  if [[ "$DRY_RUN" != "true" && "$EUID" -ne 0 ]]; then
    log_error "This script must be run as root (or with sudo)"
    log_info "Run: sudo $0 $*"
    exit 1
  fi

  # Detect CN network
  local use_cn=false
  if [[ "$INTERACTIVE" == "true" ]]; then
    echo -e "${BLUE}Detecting network conditions...${NC}"
    if detect_cn_network; then
      use_cn=true
      log_info "Detected China mainland network — enabling CN mirror configuration"
    else
      log_info "Network appears normal — no CN mirror needed"
      echo -e "${YELLOW}If you still want to configure mirrors, rerun with --non-interactive${NC}"
      exit 0
    fi
  else
    use_cn=true
  fi

  if [[ "$use_cn" == "true" ]]; then
    # Default: use DaoCloud mirror
    local selected_mirrors=("https://docker.m.daocloud.io")

    if [[ "$INTERACTIVE" == "true" ]]; then
      echo ""
      echo "Available mirror sources (select one or more, comma-separated):"
      for i in "${!MIRROR_SOURCES[@]}"; do
        echo "  [$((i+1))] ${MIRROR_SOURCES[$i]}"
      done
      echo "  [0] All of the above"
      echo ""
      read -rp "Select mirror source(s) [0]: " selection
      selection=${selection:-0}

      if [[ "$selection" == "0" ]]; then
        selected_mirrors=()
        for m in "${MIRROR_SOURCES[@]}"; do
          selected_mirrors+=("https://$m")
        done
      else
        IFS=',' read -ra choices <<< "$selection"
        selected_mirrors=()
        for c in "${choices[@]}"; do
          c=$(echo "$c" | tr -d ' ')
          idx=$((c-1))
          if [[ "$idx" -ge 0 && "$idx" -lt ${#MIRROR_SOURCES[@]} ]]; then
            selected_mirrors+=("https://${MIRROR_SOURCES[$idx]}")
          fi
        done
      fi
    fi

    echo ""
    echo -e "${BLUE}Selected mirror sources:${NC}"
    for m in "${selected_mirrors[@]}"; do
      echo "  • $m"
    done
    echo ""

    if [[ "$INTERACTIVE" == "true" ]]; then
      read -rp "Apply these settings? [Y/n]: " confirm
      confirm=${confirm:-Y}
      [[ "$confirm" =~ ^[Nn]$ ]] && log_info "Aborted" && exit 0
    fi

    # Build mirrors array for bash
    local mirrors_json="["
    local first=true
    for m in "${selected_mirrors[@]}"; do
      [[ "$first" == "false" ]] && mirrors_json+=","
      mirrors_json+="\"$m\""
      first=false
    done
    mirrors_json+="]"

    # Read existing config and merge
    local existing_json
    existing_json=$(python3 -c "
import json
try:
    with open('$DAEMON_JSON') as f:
        d = json.load(f)
except:
    d = {}
existing = d.get('registry-mirrors', [])
new = ${mirrors_json}
seen = set(existing)
for m in new:
    if m not in seen:
        existing.append(m)
d['registry-mirrors'] = existing
print(json.dumps(d, indent=2, ensure_ascii=False))
" 2>/dev/null)

    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "[dry-run] Would write to $DAEMON_JSON:"
      echo "$existing_json"
    else
      backup_daemon_json
      echo "$existing_json" > "$DAEMON_JSON"
      chmod 644 "$DAEMON_JSON"
      log_ok "Wrote $DAEMON_JSON"

      echo ""
      log_info "Docker daemon restart required. Run:"
      echo -e "  ${BOLD}sudo systemctl restart docker${NC}"
      echo ""

      read -rp "Restart Docker now? [y/N]: " restart
      restart=${restart:-N}
      if [[ "$restart" =~ ^[Yy]$ ]]; then
        systemctl restart docker
        sleep 3
        log_ok "Docker restarted"
        verify_config
      else
        log_info "Skipping restart. Please restart Docker manually."
      fi
    fi
  fi
}

main "$@"
