#!/usr/bin/env bash
# =============================================================================
# check-env.sh — Environment Detection
# Checks OS, Docker, resources, and network (CN/non-CN)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# --- OS ---
OS_ID="$(. /etc/os-release 2>/dev/null && echo "$ID" || echo unknown)"
OS_VERSION="$(. /etc/os-release 2>/dev/null && echo "$VERSION_ID" || echo unknown)"
info "OS: $OS_ID $OS_VERSION ($(uname -r))"

# --- Docker ---
if command -v docker &>/dev/null; then
    DOCKER_VER="$(docker version -f '{{.Server.Version}}' 2>/dev/null || echo unknown)"
    ok "Docker: $DOCKER_VER"
else
    fail "Docker not installed"
fi

if docker compose version &>/dev/null; then
    ok "Docker Compose: $(docker compose version --short 2>/dev/null)"
else
    warn "Docker Compose v2 not found"
fi

# --- Resources ---
MEM_GB=$(awk '/MemTotal/{printf "%.1f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo unknown)
DISK_GB=$(df -h / | awk 'NR==2{print $4}' | tr -d 'G')
DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
info "Memory: ${MEM_GB}GB | Disk free: ${DISK_GB}GB (${DISK_PCT}% used)"
(( DISK_PCT > 90 )) && warn "Disk usage above 90%!"
(( "$(echo "$MEM_GB < 2" | bc -l)" )) && warn "Less than 2GB RAM detected!"

# --- Network: CN detection ---
info "Detecting network environment..."
CN=false
if IP=$(curl -sf --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null); then
    COUNTRY=$(curl -sf --connect-timeout 5 "https://ipapi.co/${IP}/country" 2>/dev/null || echo "")
    if [[ "$COUNTRY" == "CN" ]]; then
        CN=true
        ok "IP: $IP — China mainland detected (CN_MODE recommended)"
    else
        ok "IP: $IP — $COUNTRY (international network)"
    fi
else
    warn "Could not detect public IP (offline or API unreachable)"
fi

# --- Connectivity quick check ---
for host in hub.docker.com ghcr.io gcr.io registry-1.docker.io; do
    if curl -sf --connect-timeout 3 "https://$host" >/dev/null 2>&1; then
        ok "  $host reachable"
    else
        warn "  $host unreachable"
    fi
done

# --- Summary ---
echo ""
if $CN; then
    warn "CN environment detected. Consider running: ./scripts/setup-cn-mirrors.sh"
    echo "export CN_MODE=true"
else
    ok "International network — no mirror setup needed"
    echo "export CN_MODE=false"
fi
