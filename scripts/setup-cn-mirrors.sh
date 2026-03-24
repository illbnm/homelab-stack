#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors — 配置 Docker 镜像加速
# Configures /etc/docker/daemon.json with CN mirror registries.
#
# Usage: sudo ./scripts/setup-cn-mirrors.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

DAEMON_JSON="/etc/docker/daemon.json"

# Mirror sources — primary + fallbacks
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://mirror.baidubce.com"
  "https://hub-mirror.c.163.com"
  "https://mirror.gcr.io"
)

# ---------------------------------------------------------------------------
# Step 1: Interactive confirmation
# ---------------------------------------------------------------------------
log_step "Docker Mirror Accelerator Setup"
echo ""
echo "This script configures Docker daemon with CN mirror registries."
echo "It will modify ${DAEMON_JSON}."
echo ""
read -rp "Are you deploying in mainland China (y/N)? " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  log_info "Skipping CN mirror setup. No changes made."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 2: Check root/sudo
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root (or with sudo)."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: Build mirror JSON array
# ---------------------------------------------------------------------------
log_step "Testing mirror connectivity"

available_mirrors=()
for mirror in "${MIRRORS[@]}"; do
  host="${mirror#https://}"
  if curl -sf --connect-timeout 5 --max-time 10 "$mirror" &>/dev/null; then
    log_info "[OK]   $host — reachable"
    available_mirrors+=("$mirror")
  else
    log_warn "[SLOW] $host — not reachable, skipping"
  fi
done

if [[ ${#available_mirrors[@]} -eq 0 ]]; then
  log_warn "No mirrors reachable. Using full list anyway (may work once DNS resolves)."
  available_mirrors=("${MIRRORS[@]}")
fi

# Build JSON array
mirror_json="["
for i in "${!available_mirrors[@]}"; do
  [[ $i -gt 0 ]] && mirror_json+=","
  mirror_json+="\"${available_mirrors[$i]}\""
done
mirror_json+="]"

# ---------------------------------------------------------------------------
# Step 4: Write daemon.json (merge if exists)
# ---------------------------------------------------------------------------
log_step "Configuring Docker daemon"

mkdir -p /etc/docker

if [[ -f "$DAEMON_JSON" ]]; then
  log_info "Existing ${DAEMON_JSON} found — creating backup"
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"

  # Merge: add/replace registry-mirrors key
  if command -v jq &>/dev/null; then
    jq --argjson mirrors "$mirror_json" '."registry-mirrors" = $mirrors' "$DAEMON_JSON" > "${DAEMON_JSON}.tmp"
    mv "${DAEMON_JSON}.tmp" "$DAEMON_JSON"
  else
    log_warn "jq not found — overwriting daemon.json (backup saved)"
    cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": ${mirror_json}
}
EOF
  fi
else
  cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": ${mirror_json}
}
EOF
fi

log_info "Written to ${DAEMON_JSON}:"
cat "$DAEMON_JSON"

# ---------------------------------------------------------------------------
# Step 5: Restart Docker
# ---------------------------------------------------------------------------
log_step "Restarting Docker daemon"
if systemctl is-active --quiet docker; then
  systemctl restart docker
  log_info "Docker daemon restarted."
else
  log_warn "Docker daemon not managed by systemd. Please restart Docker manually."
fi

# ---------------------------------------------------------------------------
# Step 6: Verify with test pull
# ---------------------------------------------------------------------------
log_step "Verifying mirror configuration"
if docker pull hello-world &>/dev/null; then
  log_info "${GREEN}${BOLD}✓ Mirror configuration verified — docker pull hello-world succeeded${NC}"
  docker rmi hello-world &>/dev/null || true
else
  log_error "docker pull hello-world failed. Check your network or mirror configuration."
  exit 1
fi

echo ""
log_info "CN mirror setup complete. All docker pull commands will now use accelerated mirrors."
