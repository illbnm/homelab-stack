#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Configure Docker mirror acceleration for CN networks
# Idempotent: safe to run multiple times
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

DAEMON_JSON="/etc/docker/daemon.json"

# --- Mirror list (China mainland) ---
MIRRORS=(
    "https://mirror.ccs.tencentyun.com"
    "https://hub-mirror.c.163.com"
    "https://docker.mirrors.ustc.edu.cn"
)

# --- Backup existing config ---
if [[ -f "$DAEMON_JSON" ]]; then
    cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%s)"
fi

# --- Build registry-mirrors array ---
MIRROR_JSON=$(printf '%s\n' "${MIRRORS[@]}" | jq -R . | jq -sc .)

# --- Write daemon.json preserving other keys ---
if [[ -f "$DAEMON_JSON" ]]; then
    CONTENT=$(cat "$DAEMON_JSON")
    echo "$CONTENT" | jq --argjson mirrors "$MIRROR_JSON" '.["registry-mirrors"] = $mirrors' > "$DAEMON_JSON"
else
    echo "{\"registry-mirrors\": $MIRROR_JSON}" | jq . > "$DAEMON_JSON"
fi

ok "Written registry-mirrors to $DAEMON_JSON"
echo "$MIRRORS" | while read -r m; do info "  - $m"; done

# --- Restart Docker ---
if command -v systemctl &>/dev/null; then
    systemctl restart docker
    ok "Docker restarted"
elif command -v service &>/dev/null; then
    service docker restart
    ok "Docker restarted"
else
    warn "Cannot auto-restart Docker — please restart manually"
fi

# --- Verify ---
if docker pull hello-world >/dev/null 2>&1; then
    ok "Mirror verification: hello-world pulled successfully"
else
    warn "Mirror verification: hello-world pull failed (mirror may not be working)"
fi

ok "CN mirror setup complete"
