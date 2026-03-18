#!/usr/bin/env bash
# =============================================================================
# Setup CN Docker Mirrors — 配置 Docker 国内镜像加速
# Interactively configures Docker daemon to use CN mirror registries.
# Usage: sudo ./scripts/setup-cn-mirrors.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }

DAEMON_JSON="/etc/docker/daemon.json"

# Mirror sources (primary + fallbacks)
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://mirror.gcr.io"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Docker 国内镜像加速配置"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Step 1: Interactive check ───────────────────────────────────────────────
log_step "Network environment detection"
echo -n "  Are you in mainland China (需要镜像加速)? [Y/n] "
read -r answer
case "${answer,,}" in
  n|no)
    log_info "Skipping CN mirror setup — direct registry access"
    exit 0
    ;;
esac

# ─── Step 2: Check root ─────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  log_error "This script requires root privileges"
  echo "  Run: sudo $0"
  exit 1
fi

# ─── Step 3: Check Docker installed ─────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  log_error "Docker is not installed"
  echo "  Install Docker first: curl -fsSL https://get.docker.com | sh"
  exit 1
fi

# ─── Step 4: Test mirror connectivity ────────────────────────────────────────
log_step "Testing mirror connectivity..."
AVAILABLE_MIRRORS=()
for mirror in "${MIRRORS[@]}"; do
  host=$(echo "$mirror" | sed 's|https://||')
  if curl -sf --connect-timeout 5 --max-time 10 "$mirror/v2/" >/dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]${NC}   $host"
    AVAILABLE_MIRRORS+=("$mirror")
  else
    echo -e "  ${YELLOW}[SLOW]${NC} $host — may be unstable"
    AVAILABLE_MIRRORS+=("$mirror")  # Still add as fallback
  fi
done

if [[ ${#AVAILABLE_MIRRORS[@]} -eq 0 ]]; then
  log_error "No mirror sources reachable. Check your network."
  exit 1
fi

# ─── Step 5: Backup existing config ─────────────────────────────────────────
if [[ -f "$DAEMON_JSON" ]]; then
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
  log_info "Backed up existing config to ${DAEMON_JSON}.bak.*"
fi

# ─── Step 6: Write daemon.json ──────────────────────────────────────────────
log_step "Configuring Docker daemon..."

# Build mirrors JSON array
MIRRORS_JSON=$(printf '%s\n' "${AVAILABLE_MIRRORS[@]}" | jq -R . | jq -s .)

# Merge with existing config or create new
if [[ -f "$DAEMON_JSON" ]]; then
  # Merge with existing config
  jq --argjson mirrors "$MIRRORS_JSON" '. + {"registry-mirrors": $mirrors}' "$DAEMON_JSON" > "${DAEMON_JSON}.tmp"
  mv "${DAEMON_JSON}.tmp" "$DAEMON_JSON"
else
  # Create new config
  mkdir -p /etc/docker
  jq -n --argjson mirrors "$MIRRORS_JSON" '{"registry-mirrors": $mirrors}' > "$DAEMON_JSON"
fi

log_info "Written to $DAEMON_JSON"
echo "  Mirrors configured:"
for m in "${AVAILABLE_MIRRORS[@]}"; do
  echo "    - $m"
done

# ─── Step 7: Restart Docker ─────────────────────────────────────────────────
log_step "Restarting Docker daemon..."
if systemctl is-active --quiet docker; then
  systemctl restart docker
  log_info "Docker daemon restarted"
else
  log_warn "Docker daemon not running via systemd. Restart manually:"
  echo "  sudo systemctl restart docker"
fi

# ─── Step 8: Verify ─────────────────────────────────────────────────────────
log_step "Verifying configuration..."
echo "  Pulling test image..."
if docker pull hello-world >/dev/null 2>&1; then
  log_info "docker pull hello-world — SUCCESS"
  docker rmi hello-world >/dev/null 2>&1 || true
else
  log_warn "docker pull failed — mirrors may need time to sync"
fi

echo ""
echo "  Current mirror config:"
docker info 2>/dev/null | grep -A 10 "Registry Mirrors:" || echo "  (check docker info)"
echo ""
log_info "CN mirror setup complete"
