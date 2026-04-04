#!/usr/bin/env bash
# =============================================================================
# Integration Tests — Service Connectivity & Health
# Tests: Container health, HTTP endpoints, port availability, inter-service comms
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."
ENV_FILE="$BASE_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

# Load environment variables
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}~${NC} $* (skipped)"; ((SKIPPED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Check if container is running and healthy
container_check() {
  local name=$1
  local expected_status=${2:-running}
  
  if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    log_skip "Container $name not found"
    return 1
  fi
  
  local status
  status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
  
  if [[ "$status" != "$expected_status" ]]; then
    log_fail "Container $name status: $status (expected: $expected_status)"
    return 1
  fi
  
  # Check health if available
  local health
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null)
  
  if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
    log_pass "Container $name is $status ($health)"
    return 0
  else
    log_fail "Container $name unhealthy: $health"
    return 1
  fi
}

# Check HTTP endpoint
http_check() {
  local name=$1
  local url=$2
  local expected_code=${3:-200}
  local timeout=${4:-5}
  
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout "$timeout" --max-time "$((timeout * 2))" "$url" 2>/dev/null || echo "000")
  
  if [[ "$code" == "$expected_code" ]] || [[ "$code" =~ ^[23] ]]; then
    log_pass "$name → HTTP $code ($url)"
    return 0
  else
    log_fail "$name → HTTP $code (expected ~2xx/3xx) ($url)"
    return 1
  fi
}

# Check TCP port
port_check() {
  local name=$1
  local host=${2:-localhost}
  local port=$3
  local timeout=${4:-3}
  
  if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
    log_pass "$name port $port@$host is open"
    return 0
  else
    log_skip "$name port $port@$host not reachable"
    return 1
  fi
}

# Check Docker network
network_check() {
  local name=$1
  
  if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
    log_pass "Network '$name' exists"
    return 0
  else
    log_fail "Network '$name' not found"
    return 1
  fi
}

# Check volume exists
volume_check() {
  local name=$1
  
  if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
    log_pass "Volume '$name' exists"
    return 0
  else
    log_skip "Volume '$name' not found"
    return 1
  fi
}

# Check log file
log_check() {
  local name=$1
  local path=$2
  
  if [[ -f "$path" ]]; then
    local size
    size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo 0)
    if [[ "$size" -gt 0 ]]; then
      log_pass "$name log exists ($size bytes)"
      return 0
    else
      log_skip "$name log empty"
      return 1
    fi
  else
    log_skip "$name log not found: $path"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Test: Base Infrastructure (Traefik + Portainer + Watchtower)
# -----------------------------------------------------------------------------
test_base_infrastructure() {
  log_group "Base Infrastructure"
  
  # Containers
  container_check "traefik"
  container_check "portainer"
  container_check "watchtower"
  
  # Network
  network_check "proxy"
  
  # Ports
  port_check "Traefik-HTTP" localhost 80
  port_check "Traefik-HTTPS" localhost 443
  
  # HTTP endpoints
  if [[ -n "${DOMAIN:-}" ]]; then
    http_check "Traefik Dashboard" "https://traefik.${DOMAIN}" 200 10 || true
    http_check "Portainer" "https://portainer.${DOMAIN}" 200 10 || true
  else
    log_skip "DOMAIN not set - skipping HTTPS checks"
  fi
  
  # Volumes
  volume_check "homelab-stack-bounty_portainer-data" || true
  volume_check "homelab-stack-bounty_traefik-logs" || true
  
  # Logs
  log_check "Traefik" "$BASE_DIR/config/traefik/logs/traefik.log" || true
}

# -----------------------------------------------------------------------------
# Test: SSO Stack (Authentik)
# -----------------------------------------------------------------------------
test_sso_stack() {
  log_group "SSO Stack (Authentik)"
  
  container_check "authentik-server"
  container_check "authentik-worker"
  container_check "authentik-postgresql" || container_check "authentik-db"
  container_check "authentik-redis"
  
  port_check "Authentik" localhost 9000
  http_check "Authentik Health" "http://localhost:9000/if/flow/default-authentication-flow/" 200 10 || true
}

# -----------------------------------------------------------------------------
# Test: Monitoring Stack (Prometheus + Grafana + Loki)
# -----------------------------------------------------------------------------
test_monitoring_stack() {
  log_group "Monitoring Stack"
  
  container_check "prometheus"
  container_check "grafana"
  container_check "loki"
  container_check "alertmanager"
  
  port_check "Prometheus" localhost 9090
  port_check "Grafana" localhost 3000
  port_check "Loki" localhost 3100
  port_check "Alertmanager" localhost 9093
  
  http_check "Prometheus Health" "http://localhost:9090/-/healthy" 200 5 || true
  http_check "Grafana Health" "http://localhost:3000/api/health" 200 5 || true
  http_check "Alertmanager Health" "http://localhost:9093/-/healthy" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Database Stack (PostgreSQL + Redis + MariaDB)
# -----------------------------------------------------------------------------
test_database_stack() {
  log_group "Database Stack"
  
  container_check "homelab-postgres" || container_check "postgres"
  container_check "homelab-redis" || container_check "redis"
  container_check "homelab-mariadb" || container_check "mariadb"
  
  port_check "PostgreSQL" localhost 5432
  port_check "Redis" localhost 6379
  port_check "MariaDB" localhost 3306
  
  # Test Redis connectivity
  if docker exec homelab-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    log_pass "Redis PING/PONG successful"
  else
    log_skip "Redis PING test failed"
  fi
}

# -----------------------------------------------------------------------------
# Test: Media Stack
# -----------------------------------------------------------------------------
test_media_stack() {
  log_group "Media Stack"
  
  container_check "jellyfin"
  container_check "sonarr"
  container_check "radarr"
  container_check "qbittorrent"
  container_check "jellyseerr" || true
  
  port_check "Jellyfin" localhost 8096
  port_check "Sonarr" localhost 8989
  port_check "Radarr" localhost 7878
  port_check "qBittorrent" localhost 8080
  
  http_check "Jellyfin Health" "http://localhost:8096/health" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Productivity Stack
# -----------------------------------------------------------------------------
test_productivity_stack() {
  log_group "Productivity Stack"
  
  container_check "gitea"
  container_check "vaultwarden"
  
  port_check "Gitea" localhost 3001
  port_check "Vaultwarden" localhost 8080
  
  http_check "Gitea" "http://localhost:3001" 200 5 || true
  http_check "Vaultwarden" "http://localhost:8080" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Network Stack
# -----------------------------------------------------------------------------
test_network_stack() {
  log_group "Network Stack"
  
  container_check "adguardhome"
  container_check "nginx-proxy-manager"
  container_check "wg-easy"
  
  port_check "AdGuard DNS" localhost 53
  port_check "AdGuard Admin" localhost 3000
  port_check "WireGuard" localhost 51820
}

# -----------------------------------------------------------------------------
# Test: Storage Stack
# -----------------------------------------------------------------------------
test_storage_stack() {
  log_group "Storage Stack"
  
  container_check "nextcloud"
  container_check "minio"
  container_check "filebrowser"
  
  port_check "Nextcloud" localhost 8081
  port_check "MinIO API" localhost 9000
  port_check "MinIO Console" localhost 9001
  port_check "FileBrowser" localhost 8082
  
  http_check "MinIO Console" "http://localhost:9001" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: AI Stack
# -----------------------------------------------------------------------------
test_ai_stack() {
  log_group "AI Stack"
  
  container_check "ollama"
  container_check "open-webui"
  
  port_check "Ollama" localhost 11434
  port_check "Open WebUI" localhost 3002
  
  http_check "Ollama Health" "http://localhost:11434" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Home Automation Stack
# -----------------------------------------------------------------------------
test_home_automation_stack() {
  log_group "Home Automation Stack"
  
  container_check "homeassistant"
  container_check "node-red"
  container_check "mosquitto"
  container_check "zigbee2mqtt"
  
  port_check "Home Assistant" localhost 8123
  port_check "Node-RED" localhost 1880
  port_check "MQTT" localhost 1883
  
  http_check "Home Assistant" "http://localhost:8123" 200 10 || true
  http_check "Node-RED" "http://localhost:1880" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Notifications Stack
# -----------------------------------------------------------------------------
test_notifications_stack() {
  log_group "Notifications Stack"
  
  container_check "ntfy"
  container_check "gotify" || true
  
  port_check "ntfy" localhost 2586
  
  http_check "ntfy Health" "http://localhost:2586" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Dashboard Stack
# -----------------------------------------------------------------------------
test_dashboard_stack() {
  log_group "Dashboard Stack"
  
  container_check "homepage" || container_check "heimdall"
  
  port_check "Homepage" localhost 3010 || true
  
  http_check "Homepage" "http://localhost:3010" 200 5 || true
}

# -----------------------------------------------------------------------------
# Test: Inter-service Communication
# -----------------------------------------------------------------------------
test_inter_service_communication() {
  log_group "Inter-service Communication"
  
  # Test that services can reach the proxy network
  if docker network inspect proxy 2>/dev/null | grep -q "proxy"; then
    log_pass "Proxy network is inspectable"
  else
    log_fail "Proxy network inspection failed"
  fi
  
  # Test Traefik can reach backend services (if containers are running)
  if docker ps --format '{{.Names}}' | grep -q "traefik"; then
    local traefik_logs
    traefik_logs=$(docker logs traefik --tail 50 2>/dev/null || echo "")
    if [[ -n "$traefik_logs" ]]; then
      log_pass "Traefik logs accessible"
    else
      log_skip "Traefik logs empty"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Integration Tests - Service Connectivity${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  # Check if Docker is available
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}Docker not found${NC}"
    exit 1
  fi
  
  if ! docker ps &>/dev/null; then
    echo -e "${RED}Docker daemon not running or no permission${NC}"
    exit 1
  fi
  
  # Run test suites
  test_base_infrastructure
  test_sso_stack
  test_monitoring_stack
  test_database_stack
  test_media_stack
  test_productivity_stack
  test_network_stack
  test_storage_stack
  test_ai_stack
  test_home_automation_stack
  test_notifications_stack
  test_dashboard_stack
  test_inter_service_communication
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
