#!/usr/bin/env bash
# =============================================================================
# setup-pkg-mirrors.sh — Configure Package Manager Mirrors for China
# =============================================================================
# Configures apt, pip, npm to use domestic mirrors for faster package
# installation in mainland China network environment.
#
# Usage:
#   ./setup-pkg-mirrors.sh [--apt] [--pip] [--npm] [--all] [--restore]
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
APT_BACKUP_DIR="/var/backups/apt-sources"
PIP_CONF="$HOME/.pip/pip.conf"

# Mirror URLs
PIP_MIRROR_TSINGHUA="https://pypi.tuna.tsinghua.edu.cn/simple/"
NPM_MIRROR_TAOBAO="https://registry.npmmirror.com"

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>${NC} $*"; }

# Configure pip mirrors
configure_pip() {
  log_step "Configuring pip mirrors"

  mkdir -p "$(dirname "$PIP_CONF")"

  cat > "$PIP_CONF" <<EOF
[global]
index-url = $PIP_MIRROR_TSINGHUA
trusted-host = pypi.tuna.tsinghua.edu.cn

[install]
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

  chmod 644 "$PIP_CONF"

  log_info "pip configured with Tsinghua mirror"
  log_info "Configuration file: $PIP_CONF"

  # Test configuration
  if command -v pip &>/dev/null; then
    log_info "Testing pip configuration..."
    pip config list
  fi
}

# Configure npm mirrors
configure_npm() {
  log_step "Configuring npm mirrors"

  # Configure npm registry
  if command -v npm &>/dev/null; then
    npm config set registry "$NPM_MIRROR_TAOBAO" --global
    log_info "npm configured with Taobao mirror"
    log_info "Current npm registry:"
    npm config get registry
  else
    log_warn "npm not installed"
  fi
}

# Show current configuration
show_config() {
  log_step "Current Package Manager Configuration"

  echo
  echo "pip:"
  if [[ -f "$PIP_CONF" ]]; then
    cat "$PIP_CONF"
  else
    echo "  No pip configuration found"
  fi

  echo
  echo "npm:"
  if command -v npm &>/dev/null; then
    npm config get registry
  else
    echo "  npm not installed"
  fi
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 [OPTIONS]

${BOLD}Options:${NC}
  --pip         Configure pip mirrors
  --npm         Configure npm registry
  --all         Configure all package managers
  --show        Show current configuration
  -h, --help    Show this help message

${BOLD}Examples:${NC}
  # Configure all package managers
  $0 --all

  # Configure only pip
  $0 --pip

  # Show current configuration
  $0 --show

${BOLD}Configured Mirrors:${NC}
  pip:  Tsinghua University
  npm:  Taobao
EOF
}

# Main entry point
main() {
  local configure_pip_flag="false"
  local configure_npm_flag="false"
  local show="false"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pip)
        configure_pip_flag="true"
        shift
        ;;
      --npm)
        configure_npm_flag="true"
        shift
        ;;
      --all)
        configure_pip_flag="true"
        configure_npm_flag="true"
        shift
        ;;
      --show)
        show="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Default to --show if no options specified
  if [[ "$configure_pip_flag" == "false" && "$configure_npm_flag" == "false" && \
        "$show" == "false" ]]; then
    show="true"
  fi

  # Execute actions
  if [[ "$show" == "true" ]]; then
    show_config
    exit 0
  fi

  if [[ "$configure_pip_flag" == "true" ]]; then
    configure_pip
  fi

  if [[ "$configure_npm_flag" == "true" ]]; then
    configure_npm
  fi

  log_info "Package manager configuration complete"
}

main "$@"
