#!/usr/bin/env bash
# Usage: ./install.sh [--dry-run] [--cn]
# Robust HomeLab Stack installer with curl_retry, port/disk/memory checks, and CN mirror adaptation.
set -euo pipefail

DRY_RUN=false
CN_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --cn) CN_MODE=true ;;
  esac
done

curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 "$max_attempts"); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    echo "Attempt $i failed, retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
  done
  return 1
}

configure_pkg_mirrors_cn() {
  if [[ -f /etc/apt/sources.list ]]; then
    sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list || true
    sed -i 's|http://deb.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list || true
  fi
  if [[ -f /etc/apk/repositories ]]; then
    sed -i 's|dl-cdn.alpinelinux.org|mirrors.ustc.edu.cn|g' /etc/apk/repositories || true
  fi
}

check_system_resources() {
  local avail_gb mem_mb
  avail_gb=$(df -BG . 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' || echo 50)
  if [[ -n "$avail_gb" ]] && (( avail_gb < 5 )); then
    echo "[ERROR] Insufficient disk space (${avail_gb}GB < 5GB minimum). Aborting." >&2
    exit 1
  elif [[ -n "$avail_gb" ]] && (( avail_gb < 20 )); then
    echo "[WARN] Low disk space (${avail_gb}GB < 20GB recommended)."
  fi

  mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo 4096)
  if [[ -n "$mem_mb" ]] && (( mem_mb < 2048 )); then
    echo "[WARN] Low system memory (${mem_mb}MB < 2048MB recommended)."
  fi
}

check_port_conflicts() {
  for port in 53 80 443 3000; do
    if command -v ss >/dev/null 2>&1 && ss -tuln | grep -q ":${port} "; then
      echo "[WARN] Port ${port} is currently in use."
    fi
  done
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[INFO] Docker not found; installing Docker Engine..."
    if [[ "$DRY_RUN" == "false" ]]; then
      curl_retry -fsSL https://get.docker.com | sh
    fi
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "[WARN] Docker Compose v2 plugin not detected; please upgrade from docker-compose v1 to Docker Compose v2."
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]] && command -v usermod >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
  fi
}

check_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    echo "[INFO] Detected UFW firewall."
  elif command -v firewall-cmd >/dev/null 2>&1; then
    echo "[INFO] Detected firewalld."
  fi
}

main() {
  echo "[INFO] Starting HomeLab Stack robust installer..."
  check_system_resources
  check_port_conflicts
  check_firewall
  if [[ "$CN_MODE" == "true" && "$DRY_RUN" == "false" ]]; then
    configure_pkg_mirrors_cn
    bash ./scripts/setup-cn-mirrors.sh --yes
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] All preflight checks completed."
    exit 0
  fi
  ensure_docker
  echo "[OK] HomeLab Stack environment ready."
}

main "$@"
