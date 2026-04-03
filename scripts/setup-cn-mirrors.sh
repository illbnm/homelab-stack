#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors — Docker daemon.json mirror configuration
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

DOCKER_DAEMON="/etc/docker/daemon.json"
BACKUP_DAEMON="/etc/docker/daemon.json.bak"

usage() {
  cat <<EOF
Usage: $0 [--interactive|--cn|--restore|--status]

Configure Docker daemon with Chinese mirror registries for faster pulls.

Modes:
  --interactive   Ask user whether they are in mainland China
  --cn            Force China mirror mode (no prompt)
  --restore       Restore original daemon.json from backup
  --status        Show current mirror configuration
  --test          Test mirror speed and availability

Examples:
  $0 --interactive
  $0 --cn
  $0 --restore
  $0 --status
EOF
  exit 1
}

log_info()  { echo -e "  ${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "  ${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
log_fail()  { echo -e "  ${RED}[FAIL]${NC} $*"; }

# Supported mirror sources (ordered by reliability)
declare -a MIRRORS=(
  "https://mirror.ccs.tencentyun.com"
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
)

get_current_mirror() {
  if [[ -f "$DOCKER_DAEMON" ]]; then
    python3 -c "import json,sys; d=json.load(open('$DOCKER_DAEMON')); print(d.get('registry-mirrors',[]))" 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

write_daemon_json() {
  local mirrors_json
  mirrors_json=$(python3 -c "import json,sys; print(json.dumps(${1:-[]}, indent=2))")
  cat > "$DOCKER_DAEMON" <<EOF
{
  "registry-mirrors": ${mirrors_json}
}
EOF
  log_ok "Written $DOCKER_DAEMON"
}

interactive_prompt() {
  echo ""
  echo "=========================================="
  echo "  Docker Mirror Configuration"
  echo "=========================================="
  echo ""
  echo "Are you running this server in mainland China?"
  echo ""
  echo "  1) Yes — configure Chinese mirror accelerators"
  echo "  2) No  — restore original Docker config"
  echo ""
  read -p "Select option [1]: " choice
  case "${choice:-1}" in
    1) setup_cn ;;
    2) restore_backup ;;
    *) log_fail "Invalid choice"; exit 1 ;;
  esac
}

detect_china_ip() {
  # Simple heuristic: check if IP is in known Chinese ranges via ipinfo.io
  # Returns 0 (true) if detected China, 1 otherwise
  local ip
  ip=$(curl -sf --connect-timeout 5 --max-time 10 "https://ipinfo.io/json" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('country',''))" 2>/dev/null || echo "")
  [[ "$ip" == "CN" ]]
}

setup_cn() {
  log_info "Configuring Chinese Docker mirror accelerators..."

  # Test each mirror and pick the fastest 2
  local selected=()
  for mirror in "${MIRRORS[@]}"; do
    log_info "Testing $mirror..."
    if curl -sf --connect-timeout 3 --max-time 8 "${mirror}/v2/" &>/dev/null; then
      selected+=("$mirror")
      log_ok "$mirror is reachable"
    else
      log_warn "$mirror is not reachable"
    fi
    [[ ${#selected[@]} -ge 2 ]] && break
  done

  if [[ ${#selected[@]} -eq 0 ]]; then
    log_warn "No Chinese mirrors reachable — using defaults"
    selected=("${MIRRORS[0]}")
  fi

  # Backup existing
  if [[ -f "$DOCKER_DAEMON" ]]; then
    cp "$DOCKER_DAEMON" "$BACKUP_DAEMON"
    log_info "Backed up existing $DOCKER_DAEMON -> $BACKUP_DAEMON"
  fi

  log_info "Selected mirrors: ${selected[*]}"

  # Build JSON array
  local json_array
  json_array=$(python3 -c "import json; print(json.dumps(${selected[*]}))")
  write_daemon_json "$json_array"

  # Restart Docker
  log_info "Reloading Docker daemon..."
  if command -v systemctl &>/dev/null; then
    systemctl reload docker 2>/dev/null || systemctl restart docker
    log_ok "Docker restarted via systemctl"
  elif command -v service &>/dev/null; then
    service docker reload 2>/dev/null || service docker restart
    log_ok "Docker restarted via service"
  else
    log_warn "Could not restart Docker automatically. Please run: sudo systemctl restart docker"
  fi

  sleep 2

  # Verify
  log_info "Verifying configuration..."
  if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
    log_ok "Docker mirror configuration verified"
    docker info 2>/dev/null | grep -A5 "Registry Mirrors" | head -6
  else
    log_warn "Could not verify — run 'docker info' to check"
  fi
}

restore_backup() {
  if [[ -f "$BACKUP_DAEMON" ]]; then
    cp "$BACKUP_DAEMON" "$DOCKER_DAEMON"
    log_ok "Restored $BACKUP_DAEMON -> $DOCKER_DAEMON"
    if command -v systemctl &>/dev/null; then
      systemctl reload docker 2>/dev/null || systemctl restart docker
    fi
  else
    # Remove registry-mirrors from daemon.json
    if [[ -f "$DOCKER_DAEMON" ]]; then
      python3 -c "
import json
with open('$DOCKER_DAEMON') as f:
    d = json.load(f)
d.pop('registry-mirrors', None)
with open('$DOCKER_DAEMON', 'w') as f:
    json.dump(d, f, indent=2)
"
      log_ok "Cleared registry-mirrors from $DOCKER_DAEMON"
    fi
  fi
  log_info "Run 'sudo systemctl restart docker' to apply changes"
}

show_status() {
  echo ""
  echo "=== Docker Mirror Status ==="
  if [[ -f "$DOCKER_DAEMON" ]]; then
    echo "Config: $DOCKER_DAEMON"
    python3 -c "import json; print(json.dumps(json.load(open('$DOCKER_DAEMON')), indent=2))" 2>/dev/null || cat "$DOCKER_DAEMON"
  else
    echo "No custom config found"
  fi
  echo ""
  echo "=== Current Registry Mirrors ==="
  docker info 2>/dev/null | grep -A10 "Registry Mirrors" || echo "(none configured)"
}

test_mirrors() {
  echo ""
  echo "=== Mirror Speed Test ==="
  local mirrors=(
    "docker.io"
    "gcr.io"
    "ghcr.io"
    "k8s.gcr.io"
    "quay.io"
    "mirror.ccs.tencentyun.com"
    "docker.m.daocloud.io"
    "hub-mirror.c.163.com"
    "mirror.baidubce.com"
  )

  for host in "${mirrors[@]}"; do
    local start_ms end_ms latency
    start_ms=$(date +%s%3N)
    if curl -sf --connect-timeout 3 --max-time 8 "https://$host/v2/" &>/dev/null; then
      end_ms=$(date +%s%3N)
      latency=$((end_ms - start_ms))
      echo -e "  ${GREEN}[OK]${NC}   $host — ${latency}ms"
    else
      echo -e "  ${RED}[FAIL]${NC} $host — unreachable"
    fi
  done
}

# Main
case "${1:-}" in
  --interactive) interactive_prompt ;;
  --cn)          setup_cn ;;
  --restore)     restore_backup ;;
  --status)      show_status ;;
  --test)        test_mirrors ;;
  -h|--help)    usage ;;
  *)            usage ;;
esac
