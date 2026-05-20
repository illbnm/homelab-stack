#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_FILE=${LOG_FILE:-$HOME/.homelab/install.log}
AUTO_INSTALL_DOCKER=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
log_warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }
log_step()  { printf '\n%b==> %s%b\n' "$BLUE$BOLD" "$*" "$NC"; }

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--no-auto-install-docker]

Runs preflight checks, optionally installs Docker on supported Linux systems,
configures the environment, checks connectivity, and starts the base stack.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-auto-install-docker) AUTO_INSTALL_DOCKER=false; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup() {
  local code=$?
  if [[ "$code" -ne 0 ]]; then
    log_error "Installation failed. Diagnostics: ./scripts/diagnose.sh. Log: $LOG_FILE"
  fi
}
trap cleanup EXIT

retry() {
  local attempts=$1 delay=$2
  shift 2
  local count=1
  until "$@"; do
    if [[ "$count" -ge "$attempts" ]]; then
      return 1
    fi
    log_warn "Command failed, retrying in ${delay}s ($count/$attempts): $*"
    sleep "$delay"
    delay=$((delay * 2))
    count=$((count + 1))
  done
}

require_root_for_install() {
  if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required to install Docker automatically. Re-run as root or install Docker manually."
    exit 1
  fi
}

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_docker_ubuntu_debian() {
  retry 3 2 as_root apt-get update
  retry 3 2 as_root apt-get install -y ca-certificates curl gnupg lsb-release
  if ! [[ -f /etc/apt/keyrings/docker.gpg ]]; then
    as_root install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/"$(. /etc/os-release && printf '%s' "$ID")"/gpg | as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    as_root chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  local distro codename arch
  distro=$(. /etc/os-release && printf '%s' "$ID")
  codename=$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")
  arch=$(dpkg --print-architecture)
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/%s %s stable\n' "$arch" "$distro" "$codename" | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
  retry 3 2 as_root apt-get update
  retry 3 2 as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_centos() {
  retry 3 2 as_root yum install -y yum-utils
  as_root yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  retry 3 2 as_root yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_arch() {
  retry 3 2 as_root pacman -Sy --noconfirm docker docker-compose
}

auto_install_docker() {
  command -v docker >/dev/null 2>&1 && return 0
  [[ "$AUTO_INSTALL_DOCKER" == true ]] || return 0
  require_root_for_install
  [[ -f /etc/os-release ]] || { log_warn "Cannot detect OS for Docker auto-install."; return 0; }
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) install_docker_ubuntu_debian ;;
    centos|rhel|fedora|rocky|almalinux) install_docker_centos ;;
    arch|manjaro) install_docker_arch ;;
    *) log_warn "Unsupported OS for Docker auto-install: ${ID:-unknown}"; return 0 ;;
  esac
  as_root systemctl enable --now docker || true
}

check_compose_v2() {
  if docker compose version >/dev/null 2>&1; then
    log_info "Docker Compose v2 found: $(docker compose version --short 2>/dev/null || docker compose version)"
  elif command -v docker-compose >/dev/null 2>&1; then
    log_error "docker-compose v1 detected. Install the Docker Compose v2 plugin before continuing."
    exit 1
  else
    log_error "Docker Compose v2 plugin is missing."
    exit 1
  fi
}

check_resources() {
  local free_gb mem_mb
  free_gb=$(df -BG "$ROOT_DIR" | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  mem_mb=$(awk '/MemTotal/ {printf "%d", $2 / 1024}' /proc/meminfo 2>/dev/null || printf 0)
  [[ "$free_gb" -ge 10 ]] || log_warn "Only ${free_gb}GB free; 10GB+ recommended."
  [[ "$mem_mb" -ge 4096 ]] || log_warn "Only ${mem_mb}MB RAM; 4GB+ recommended."
}

check_user_group() {
  if [[ "$(id -u)" -ne 0 ]] && ! id -nG | tr ' ' '\n' | grep -qx docker; then
    log_warn "Current user is not in docker group. You may need: sudo usermod -aG docker $USER"
  fi
}

check_firewall() {
  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then
    log_warn "ufw is active; ensure ports 80 and 443 are allowed."
  fi
  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    log_warn "firewalld is active; ensure ports 80 and 443 are allowed."
  fi
}

ensure_proxy_network() {
  docker network inspect proxy >/dev/null 2>&1 || docker network create proxy >/dev/null
}

ensure_acme() {
  mkdir -p "$ROOT_DIR/config/traefik"
  touch "$ROOT_DIR/config/traefik/acme.json"
  chmod 600 "$ROOT_DIR/config/traefik/acme.json"
}

print_banner() {
  printf '\n%b  HomeLab Stack v1.0.0%b\n\n' "$BOLD" "$NC"
}

main() {
  cd "$ROOT_DIR"
  print_banner
  log_step "Installing or validating Docker"
  auto_install_docker
  check_compose_v2
  retry 3 2 docker info >/dev/null

  log_step "Connectivity check"
  if ! "$ROOT_DIR/scripts/check-connectivity.sh"; then
    log_warn "Connectivity is degraded. If you are in mainland China, run scripts/setup-cn-mirrors.sh and scripts/localize-images.sh --cn."
  fi

  log_step "Dependency and host checks"
  bash "$ROOT_DIR/scripts/check-deps.sh" || true
  check_resources
  check_user_group
  check_firewall
  ensure_proxy_network
  ensure_acme

  log_step "Environment configuration"
  if [[ ! -f "$ROOT_DIR/.env" ]]; then
    bash "$ROOT_DIR/scripts/setup-env.sh"
  else
    log_warn ".env already exists, skipping setup. Remove it to reconfigure."
  fi

  log_step "Creating data directories"
  mkdir -p data/traefik/certs data/portainer data/prometheus data/grafana data/loki data/authentik/media data/nextcloud data/gitea data/vaultwarden

  log_step "Launching base infrastructure"
  retry 3 3 docker compose -f "$ROOT_DIR/stacks/base/docker-compose.yml" up -d
  "$ROOT_DIR/scripts/wait-healthy.sh" --stack base --timeout 300

  log_info "Base infrastructure is up."
  log_info "Next: ./scripts/stack-manager.sh start sso"
}

main "$@"
