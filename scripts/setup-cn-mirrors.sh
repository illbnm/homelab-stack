#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh - Docker 镜像加速配置工具
# 为中国大陆网络环境配置 Docker 镜像加速
# =============================================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

# Mirror sources (priority order)
CN_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://docker.1ms.run"
  "https://docker.fxxk.dedyn.io"
  "https://dockerpull.org"
  "https://docker.rainbond.cc"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://mirror.gcr.io"
)

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)"

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Detect if in China
detect_cn_network() {
  log_step "Detecting network environment..."

  # Method 1: Check timezone
  local tz
  tz=$(timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 || echo "")
  if [[ "$tz" == "Asia/Shanghai" || "$tz" == "Asia/Chongqing" || "$tz" == "Asia/Hong_Kong" ]]; then
    log_info "Timezone indicates China: $tz"
    return 0
  fi

  # Method 2: Check locale
  local lang
  lang="${LANG:-}"
  if [[ "$lang" == "zh_CN"* || "$lang" == "zh_TW"* ]]; then
    log_info "Locale indicates Chinese: $lang"
    return 0
  fi

  # Method 3: Connectivity test
  # Try to reach Baidu (China) vs Google (blocked in China)
  local baidu_reachable=false
  local google_reachable=false

  if curl -sf --connect-timeout 3 --max-time 5 "https://www.baidu.com" &>/dev/null; then
    baidu_reachable=true
  fi

  if curl -sf --connect-timeout 3 --max-time 5 "https://www.google.com" &>/dev/null; then
    google_reachable=true
  fi

  if $baidu_reachable && ! $google_reachable; then
    log_info "Network test indicates China (Baidu reachable, Google blocked)"
    return 0
  fi

  return 1
}

# Test mirror speed
test_mirror_speed() {
  local mirror="$1"
  local start end duration

  start=$(date +%s%3N 2>/dev/null || date +%s)000
  if curl -sf --connect-timeout 5 --max-time 10 "${mirror}/v2/" &>/dev/null; then
    end=$(date +%s%3N 2>/dev/null || date +%s)000
    duration=$(( end - start ))
    echo "$duration"
    return 0
  fi
  echo "9999"
  return 1
}

# Select best mirrors
select_best_mirrors() {
  log_step "Testing mirror speeds..."

  declare -A mirror_speeds
  local fastest_mirrors=()

  for mirror in "${CN_MIRRORS[@]}"; do
    log_info "Testing $mirror..."
    local speed
    speed=$(test_mirror_speed "$mirror")
    mirror_speeds["$mirror"]="$speed"

    if [[ "$speed" != "9999" ]]; then
      log_info "  → ${speed}ms"
    else
      log_warn "  → unreachable"
    fi
  done

  # Sort by speed and select top 3
  local sorted_mirrors
  sorted_mirrors=$(for mirror in "${!mirror_speeds[@]}"; do
    echo "${mirror_speeds[$mirror]} $mirror"
  done | sort -n | head -3 | awk '{print $2}')

  while IFS= read -r mirror; do
    [[ -n "$mirror" ]] && fastest_mirrors+=("$mirror")
  done <<< "$sorted_mirrors"

  if [[ ${#fastest_mirrors[@]} -eq 0 ]]; then
    log_error "No mirrors are reachable"
    return 1
  fi

  echo "${fastest_mirrors[@]}"
}

# Backup existing daemon.json
backup_config() {
  if [[ -f "$DAEMON_JSON" ]]; then
    cp "$DAEMON_JSON" "$BACKUP_FILE"
    log_info "Backed up existing config to: $BACKUP_FILE"
  fi
}

# Generate daemon.json content
generate_daemon_json() {
  local mirrors_json
  mirrors_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)

  # Read existing config if available
  local existing_config="{}"
  if [[ -f "$DAEMON_JSON" ]]; then
    existing_config=$(cat "$DAEMON_JSON" 2>/dev/null || echo "{}")
  fi

  # Merge with new registry-mirrors
  echo "$existing_config" | jq --argjson mirrors "$mirrors_json" '. + {"registry-mirrors": $mirrors}' 2>/dev/null || {
    # Fallback if jq fails - create new config
    cat <<EOF
{
  "registry-mirrors": $mirrors_json
}
EOF
  }
}

# Configure Docker daemon
configure_docker() {
  local mirrors=("$@")

  log_step "Configuring Docker daemon..."
  backup_config

  local new_config
  new_config=$(generate_daemon_json "${mirrors[@]}")

  # Ensure directory exists
  mkdir -p /etc/docker

  # Write new config
  echo "$new_config" | jq '.' > "$DAEMON_JSON" 2>/dev/null || echo "$new_config" > "$DAEMON_JSON"

  log_info "Configuration written to $DAEMON_JSON"

  # Restart Docker
  log_step "Restarting Docker daemon..."
  if command -v systemctl &>/dev/null; then
    systemctl restart docker
    log_info "Docker restarted via systemctl"
  elif command -v service &>/dev/null; then
    service docker restart
    log_info "Docker restarted via service"
  else
    log_warn "Please restart Docker manually: pkill -HUP dockerd"
  fi
}

# Verify configuration
verify_config() {
  log_step "Verifying configuration..."

  local max_attempts=5
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    log_info "Attempt $attempt/$max_attempts: Testing docker pull..."

    if docker pull --quiet hello-world &>/dev/null; then
      log_info "${GREEN}✓ Docker pull test successful!${NC}"

      # Show which mirror was used (if possible)
      local pull_time
      # shellcheck disable=SC2034
      pull_time=$(date +%s)
      docker pull alpine:latest &>/dev/null
      log_info "Image pull completed successfully"

      return 0
    fi

    log_warn "Attempt $attempt failed, waiting..."
    sleep 5
    ((attempt++))
  done

  log_error "Docker pull test failed after $max_attempts attempts"
  log_warn "Consider restoring backup: cp $BACKUP_FILE $DAEMON_JSON && systemctl restart docker"
  return 1
}

# Interactive mode
interactive_setup() {
  log_step "Interactive Setup"
  echo ""
  echo -e "${BOLD}This script will configure Docker to use mirror acceleration.${NC}"
  echo ""

  local in_china=""

  # Auto-detect
  if detect_cn_network; then
    echo -e "${GREEN}Auto-detected: You appear to be in China${NC}"
    read -r -p "Use CN mirrors? [Y/n] " in_china
    in_china="${in_china:-Y}"
  else
    echo -e "${YELLOW}Auto-detected: You may not be in China${NC}"
    read -r -p "Configure CN mirrors anyway? [y/N] " in_china
    in_china="${in_china:-N}"
  fi

  if [[ ! "$in_china" =~ ^[Yy] ]]; then
    log_info "Skipping CN mirror configuration"
    exit 0
  fi

  # Select mirrors
  echo ""
  log_step "Selecting best mirrors..."
  local best_mirrors
  best_mirrors=$(select_best_mirrors)

  if [[ -z "$best_mirrors" ]]; then
    log_error "No reachable mirrors found"
    exit 1
  fi

  echo ""
  log_info "Selected mirrors:"
  for mirror in $best_mirrors; do
    echo "  - $mirror"
  done

  echo ""
  read -r -p "Configure these mirrors? [Y/n] " confirm
  confirm="${confirm:-Y}"

  if [[ ! "$confirm" =~ ^[Yy] ]]; then
    log_info "Cancelled by user"
    exit 0
  fi

  # Configure
  # shellcheck disable=SC2086
  configure_docker $best_mirrors

  # Verify
  verify_config
}

# Show current config
show_config() {
  log_step "Current Docker Mirror Configuration"

  if [[ -f "$DAEMON_JSON" ]]; then
    echo "Config file: $DAEMON_JSON"
    jq '.' "$DAEMON_JSON" 2>/dev/null || cat "$DAEMON_JSON"
  else
    log_warn "No daemon.json found"
  fi
}

# Remove CN mirrors
remove_mirrors() {
  log_step "Removing CN mirror configuration..."

  if [[ -f "$DAEMON_JSON" ]]; then
    backup_config
    jq 'del(.["registry-mirrors"])' "$DAEMON_JSON" > "${DAEMON_JSON}.tmp" && mv "${DAEMON_JSON}.tmp" "$DAEMON_JSON"
    log_info "Mirrors removed from configuration"

    if command -v systemctl &>/dev/null; then
      systemctl restart docker
    fi
  else
    log_info "No configuration to remove"
  fi
}

# Usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -i, --interactive    Interactive setup (default)
  -y, --yes            Non-interactive, auto-confirm
  -s, --show           Show current configuration
  -r, --remove         Remove CN mirrors
  -h, --help           Show this help

Examples:
  $0                   # Interactive setup
  $0 -y                # Auto setup without prompts
  $0 --show            # Show current config
  $0 --remove          # Remove mirrors

Supported mirrors:
  - docker.m.daocloud.io (DaoCloud)
  - docker.1ms.run
  - hub-mirror.c.163.com (NetEase)
  - mirror.baidubce.com (Baidu)
  - mirror.gcr.io
  - And more...

EOF
  exit 0
}

# Main
main() {
  local mode="interactive"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -i|--interactive) mode="interactive" ;;
      -y|--yes) mode="auto" ;;
      -s|--show) show_config; exit 0 ;;
      -r|--remove) check_root; remove_mirrors; exit 0 ;;
      -h|--help) usage ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
  done

  check_root

  if [[ "$mode" == "auto" ]]; then
    log_step "Auto mode: Configuring CN mirrors..."
    local best_mirrors
    best_mirrors=$(select_best_mirrors)
    if [[ -n "$best_mirrors" ]]; then
      # shellcheck disable=SC2086
      configure_docker $best_mirrors
      verify_config
    fi
  else
    interactive_setup
  fi
}

main "$@"
