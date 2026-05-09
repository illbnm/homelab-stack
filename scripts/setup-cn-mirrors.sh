#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — CN Mirror Setup
# Configures Docker daemon for China mainland network.
# Usage: ./setup-cn-mirrors.sh [--apply|--restore|--check]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.bak.$(date +%s)"
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://docker.mirrors.ustc.edu.cn"
)

ACTION="${1:---apply}"

check_in_china() {
  local result
  result=$(curl -sf --connect-timeout 3 "https://www.baidu.com" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  if [ "$result" = "200" ]; then
    local latency
    latency=$(curl -sf --connect-timeout 3 -o /dev/null -w "%{time_total}" "https://www.baidu.com" 2>/dev/null || echo "999")
    if (( $(echo "$latency < 2" | bc -l 2>/dev/null || echo 0) )); then
      log_info "Detected China mainland network (Baidu: ${latency}s)"
      return 0
    fi
  fi
  return 1
}

apply_mirrors() {
  log_info "Configuring Docker registry mirrors..."
  
  # Backup
  if [ -f "$DAEMON_JSON" ]; then
    cp "$DAEMON_JSON" "$BACKUP_FILE"
    log_info "Backed up to $BACKUP_FILE"
  fi

  # Build mirrors JSON array
  local mirrors_json="["
  for m in "${MIRRORS[@]}"; do
    mirrors_json+="\"$m\","
  done
  mirrors_json="${mirrors_json%,}]"

  # Write config
  cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": $mirrors_json,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

  # Restart Docker
  if command -v systemctl &>/dev/null; then
    systemctl restart docker
  else
    service docker restart
  fi
  
  sleep 3
  if docker pull hello-world:latest > /dev/null 2>&1; then
    log_info "Docker registry mirrors configured successfully"
    docker rmi hello-world:latest > /dev/null 2>&1
  else
    log_error "Docker pull failed after mirror configuration"
    return 1
  fi
}

restore_mirrors() {
  local latest_backup=$(ls -t /etc/docker/daemon.json.bak.* 2>/dev/null | head -1)
  if [ -n "$latest_backup" ]; then
    cp "$latest_backup" "$DAEMON_JSON"
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null
    log_info "Restored from $latest_backup"
  else
    rm -f "$DAEMON_JSON"
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null
    log_info "Removed custom Docker config"
  fi
}

case "$ACTION" in
  --apply)
    apply_mirrors
    ;;
  --restore)
    restore_mirrors
    ;;
  --check)
    if check_in_china; then
      log_info "Running in China — mirrors recommended"
    else
      log_info "Not in China — mirrors not needed"
    fi
    ;;
  *)
    echo "Usage: setup-cn-mirrors.sh [--apply|--restore|--check]"
    exit 1
    ;;
esac
