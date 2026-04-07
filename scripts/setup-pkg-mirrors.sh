#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

configure_pip() {
  log_step "Configuring pip (Python) mirror"
  
  local pip_conf="$HOME/.pip/pip.conf"
  mkdir -p "$(dirname "$pip_conf")"
  
  cat > "$pip_conf" << PIP_EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
PIP_EOF
  
  log_info "pip configured to use Tsinghua mirror"
  log_info "Config file: $pip_conf"
}

configure_npm() {
  log_step "Configuring npm (Node.js) mirror"
  
  if ! command -v npm &> /dev/null; then
    log_warn "npm not installed, skipping"
    return
  fi
  
  npm config set registry https://registry.npmmirror.com
  
  log_info "npm configured to use npmmirror"
  log_info "Current registry: $(npm config get registry)"
}

configure_go() {
  log_step "Configuring Go modules proxy"
  
  if ! command -v go &> /dev/null; then
    log_warn "Go not installed, skipping"
    return
  fi
  
  go env -w GOPROXY=https://goproxy.cn,direct
  
  log_info "Go configured to use goproxy.cn"
  log_info "Current proxy: $(go env GOPROXY)"
}

restore_defaults() {
  log_step "Restoring default package manager settings"
  
  if [[ -f "$HOME/.pip/pip.conf" ]]; then
    rm "$HOME/.pip/pip.conf"
    log_info "Removed pip configuration"
  fi
  
  if command -v npm &> /dev/null; then
    npm config set registry https://registry.npmjs.org
    log_info "Restored npm to default registry"
  fi
  
  if command -v go &> /dev/null; then
    go env -w GOPROXY=https://proxy.golang.org,direct
    log_info "Restored Go to default proxy"
  fi
  
  log_info "All package managers restored to defaults"
}

usage() {
  cat << USAGE_EOF
Usage: $0 [OPTIONS]

Options:
  --all       Configure all available package managers
  --pip       Configure pip only
  --npm       Configure npm only
  --go        Configure Go modules only
  --restore   Restore default settings
  --help      Show this help message

Examples:
  $0 --all      # Configure all package managers
  $0 --pip      # Configure pip only
  $0 --restore  # Restore defaults
USAGE_EOF
  exit 1
}

main() {
  local configure_all=false
  local configure_pip_flag=false
  local configure_npm_flag=false
  local configure_go_flag=false
  local restore_flag=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --all)
        configure_all=true
        shift
        ;;
      --pip)
        configure_pip_flag=true
        shift
        ;;
      --npm)
        configure_npm_flag=true
        shift
        ;;
      --go)
        configure_go_flag=true
        shift
        ;;
      --restore)
        restore_flag=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  if [[ "$restore_flag" == true ]]; then
    restore_defaults
    exit 0
  fi
  
  if [[ "$configure_all" == true ]]; then
    configure_pip
    configure_npm
    configure_go
  else
    [[ "$configure_pip_flag" == true ]] && configure_pip
    [[ "$configure_npm_flag" == true ]] && configure_npm
    [[ "$configure_go_flag" == true ]] && configure_go
  fi
  
  if [[ "$configure_all" == false && "$configure_pip_flag" == false && \
        "$configure_npm_flag" == false && "$configure_go_flag" == false ]]; then
    usage
  fi
  
  log_info "✓ Package mirror configuration complete!"
}

main "$@"
