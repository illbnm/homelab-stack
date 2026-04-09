#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — CN Docker Mirror Setup
# Configures Docker daemon to use China mainland registry mirrors.
#
# Usage: sudo ./scripts/setup-cn-mirrors.sh [--auto] [--restore]
# =============================================================================
set -euo pipefail

AUTO_MODE=false
RESTORE=false
for arg in "$@"; do
  case "$arg" in
    --auto)    AUTO_MODE=true ;;
    --restore) RESTORE=true ;;
    --help)    echo "Usage: $0 [--auto] [--restore]"; exit 0 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.bak.homelab"

# Mirror sources (ordered by reliability)
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://mirror.gcr.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
)

# Check root
if [ "$(id -u)" -ne 0 ]; then
  log_error "This script requires root. Run with sudo."
  exit 1
fi

# Restore mode
if $RESTORE; then
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DAEMON_JSON"
    systemctl restart docker
    log_info "Restored original daemon.json from backup"
    rm -f "$BACKUP_FILE"
  else
    log_warn "No backup found at $BACKUP_FILE"
  fi
  exit 0
fi

# Ask if in China (unless --auto)
IN_CN=false
if $AUTO_MODE; then
  # Auto-detect: try to reach docker.io, if slow assume CN
  latency=$(curl -o /dev/null -s -w "%{time_total}" \
    --connect-timeout 5 --max-time 10 https://registry-1.docker.io/v2/ 2>/dev/null || echo "99")
  if [ "$(echo "$latency > 2" | bc -l 2>/dev/null || echo 1)" -eq 1 ]; then
    IN_CN=true
  fi
else
  echo -e "${CYAN}是否在中国大陆部署？[y/N]${NC}"
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    IN_CN=true
  fi
fi

if ! $IN_CN; then
  log_info "Not in China mainland — no mirror configuration needed."
  exit 0
fi

log_info "Detected China mainland network — configuring Docker mirrors..."

# Backup existing config
if [ -f "$DAEMON_JSON" ]; then
  cp "$DAEMON_JSON" "$BACKUP_FILE"
  log_info "Backed up existing daemon.json to $BACKUP_FILE"
fi

# Build mirror list string
mirror_list=""
for mirror in "${MIRRORS[@]}"; do
  mirror_list="${mirror_list}\"${mirror}\",
    "
done
mirror_list="${mirror_list%,*}"  # Remove trailing comma

# Build daemon.json
existing_config=""
if [ -f "$BACKUP_FILE" ]; then
  existing_config=$(cat "$BACKUP_FILE")
fi

# Use jq if available, otherwise raw
if command -v jq &>/dev/null; then
  if [ -n "$existing_config" ] && [ "$existing_config" != "" ]; then
    echo "$existing_config" | jq ". + {\"registry-mirrors\": $(printf '%s\n' "${MIRRORS[@]}" | jq -R . | jq -s .)}" > "$DAEMON_JSON"
  else
    echo "{\"registry-mirrors\": $(printf '%s\n' "${MIRRORS[@]}" | jq -R . | jq -s .)}" > "$DAEMON_JSON"
  fi
else
  cat > "$DAEMON_JSON" << DAEMONJSON
{
  "registry-mirrors": [
    ${mirror_list}
  ]
}
DAEMONJSON
fi

log_info "Wrote mirror configuration to $DAEMON_JSON"

# Restart Docker
log_info "Restarting Docker daemon..."
systemctl restart docker

# Wait for Docker
sleep 3
if ! systemctl is-active --quiet docker; then
  log_error "Docker failed to restart! Restoring backup..."
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DAEMON_JSON"
    systemctl restart docker
  fi
  exit 1
fi

# Verify
log_info "Verifying mirror configuration..."
if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
  log_info "Mirror configuration active:"
  docker info 2>/dev/null | grep -A5 "Registry Mirrors" || true
else
  log_warn "Could not verify mirrors in docker info"
fi

# Test pull
log_info "Testing docker pull with mirror..."
if docker pull --quiet hello-world 2>/dev/null; then
  log_info "✅ docker pull hello-world succeeded — mirrors are working!"
else
  log_warn "docker pull hello-world failed — mirrors may not be fully functional"
  log_warn "Try manual test: docker pull alpine"
fi

log_info ""
log_info "Done! You can also run: ./scripts/localize-images.sh --cn"
log_info "To restore original config: sudo $0 --restore"
