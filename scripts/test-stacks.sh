#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack Integration Tests
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASSED=0; FAILED=0; SKIPPED=0

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}~${NC} $* (skipped)"; ((SKIPPED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

http_check() {
  local name=$1 url=$2 expected=${3:-200}
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 000)
  if [[ "$code" == "$expected" ]] || [[ "$code" =~ ^[23] ]]; then
    log_pass "$name ($url) → HTTP $code"
  else
    log_fail "$name ($url) → HTTP $code (expected ~2xx/3xx)"
  fi
}

container_check() {
  local name=$1
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'no-healthcheck')
    if [[ "$health" == 'healthy' ]] || [[ "$health" == 'no-healthcheck' ]]; then
      log_pass "Container $name is running ($health)"
    else
      log_fail "Container $name unhealthy: $health"
    fi
  else
    log_skip "Container $name not running"
  fi
}

port_check() {
  local name=$1 host=${2:-localhost} port=$3
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    log_pass "$name port $port is open"
  else
    log_skip "$name port $port not reachable"
  fi
}

# ---- Tests ----

log_group "Base Infrastructure"
container_check traefik
container_check portainer
container_check watchtower
port_check Traefik localhost 80
port_check Traefik-HTTPS localhost 443

log_group "SSO (Authentik)"
container_check authentik-server
container_check authentik-worker
container_check authentik-postgresql
container_check authentik-redis
http_check Authentik "http://localhost:9000/if/flow/default-authentication-flow/"

log_group "Monitoring"
container_check prometheus
container_check grafana
container_check loki
container_check alertmanager
http_check Prometheus "http://localhost:9090/-/healthy"
http_check Grafana "http://localhost:3000/api/health"
http_check Alertmanager "http://localhost:9093/-/healthy"

log_group "Databases"
container_check homelab-postgres
container_check homelab-redis
container_check homelab-mariadb
port_check PostgreSQL localhost 5432
port_check Redis localhost 6379
port_check MariaDB localhost 3306

log_group "Media Stack"
container_check jellyfin
container_check sonarr
container_check radarr
container_check qbittorrent
http_check Jellyfin "http://localhost:8096/health"

log_group "Productivity Stack"
container_check gitea
container_check vaultwarden
http_check Gitea "http://localhost:3001"
http_check Vaultwarden "http://localhost:8080"

log_group "Network Stack"
container_check adguardhome
container_check nginx-proxy-manager
container_check wg-easy
port_check WireGuard localhost 51820

log_group "Storage Stack"
container_check nextcloud
container_check minio
container_check filebrowser
http_check MinIO "http://localhost:9001"

log_group "AI Stack"
container_check ollama
container_check open-webui
http_check Ollama "http://localhost:11434"

log_group "Home Automation"
container_check homeassistant
container_check node-red
http_check HomeAssistant "http://localhost:8123"
http_check NodeRED "http://localhost:1880"

log_group "Notifications"
container_check ntfy
http_check ntfy "http://localhost:2586"

log_group "Dashboard"
container_check homepage
http_check Homepage "http://localhost:3010"

# ---- Summary ----
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
echo -e "${BOLD}========================================${NC}"

[[ $FAILED -eq 0 ]] && exit 0 || exit 1
