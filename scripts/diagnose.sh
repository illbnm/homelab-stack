#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — 完整系统诊断脚本
# 收集 Docker 版本、系统信息、容器状态、日志、网络连通性
# 输出到终端和可选的文件
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
OUTPUT_FILE=""
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'
SEPARATOR="════════════════════════════════════════════════════"

# 解析参数
for arg in "$@"; do
  case $arg in
    -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-o output.txt]"
      echo "  -o, --output <file>  Write output to file"
      exit 0 ;;
  esac
done

# 如果有输出文件，重定向所有输出
if [[ -n "$OUTPUT_FILE" ]]; then
  exec > >(tee "$OUTPUT_FILE")
  echo "[$(date)] Output logging to $OUTPUT_FILE"
fi

section() {
  echo ""
  echo -e "${BOLD}╔═ $1 ════════════════════════════════════════════════╗${NC}"
}

subsection() {
  echo ""
  echo -e "${BLUE}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# 1. System Info
# ============================================================
section "1. System Information"
echo "Timestamp:     $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Hostname:      $(hostname)"
echo "Uptime:        $(uptime -p 2>/dev/null || uptime)"
echo "OS:            $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || uname -s)"
echo "Kernel:        $(uname -r)"
echo "Architecture:  $(uname -m)"
echo "Shell:         $SHELL ($BASH_VERSION)"

subsection "CPU"
grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs
echo "CPU Cores:     $(nproc 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo 'unknown')"

subsection "Memory"
free -h 2>/dev/null || echo "free not available"
echo ""
echo "Memory pressure:"
local mem_available mem_total
mem_available=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
mem_total=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
if [[ -n "$mem_available" && -n "$mem_total" ]]; then
  local pct=$((100 - (mem_available * 100 / mem_total)))
  echo "  Used: ${pct}%"
  if [[ $pct -gt 90 ]]; then
    echo -e "  ${RED}⚠ WARNING: Memory usage > 90%${NC}"
  elif [[ $pct -gt 75 ]]; then
    echo -e "  ${YELLOW}⚠ Memory usage > 75%${NC}"
  fi
fi

subsection "Disk"
df -h / /var/lib/docker 2>/dev/null | grep -v "Filesystem" | while read -r line; do
  echo "  $line"
done
echo ""
echo "Disk I/O:"
iostat -dx 2>/dev/null | head -10 || echo "  iostat not available"

subsection "Load Average"
cat /proc/loadavg 2>/dev/null || uptime
echo ""

# ============================================================
# 2. Docker Info
# ============================================================
section "2. Docker"
echo "Docker version:"
docker --version 2>/dev/null || echo "  docker not found"
echo "Docker Compose version:"
docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "  not found"
echo "Docker daemon:"
docker info 2>/dev/null | grep -E "Server Version|Storage Driver|Logging Driver|Kernel Version|Cgroup Driver" | sed 's/^/  /' || echo "  daemon not accessible"

subsection "Docker Disk Usage"
docker system df 2>/dev/null || echo "  cannot query docker"

# ============================================================
# 3. Container Status
# ============================================================
section "3. Container Status"
echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" 2>/dev/null || echo "  cannot list containers"

echo ""
echo "All containers (including stopped):"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | head -20 || echo "  cannot list containers"

subsection "Unhealthy Containers"
docker ps -a --filter "health=unhealthy" --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "  none found"

subsection "Restarting Containers"
docker ps -a --filter "status=restarting" --format "{{.Names}}" 2>/dev/null | while read -r name; do
  if [[ -n "$name" ]]; then
    echo "  $name:"
    docker inspect --format '{{.State.RestartingReason}}' "$name" 2>/dev/null | sed 's/^/    /'
  fi
done

# ============================================================
# 4. Docker Networks
# ============================================================
section "4. Docker Networks"
docker network ls 2>/dev/null || echo "  cannot list networks"
echo ""
echo "Proxy network (expected: external):"
docker network inspect proxy 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  Name:', d[0]['Name'])
print('  Driver:', d[0]['Driver'])
print('  Scope:', d[0]['Scope'])
external = d[0].get('External', False)
print('  External:', external)
" 2>/dev/null || echo "  proxy network not found or not accessible"

# ============================================================
# 5. Docker Volumes
# ============================================================
section "5. Docker Volumes"
docker volume ls 2>/dev/null | head -30 || echo "  cannot list volumes"

# ============================================================
# 6. Error Logs (recent)
# ============================================================
section "6. Recent Error Logs"
echo "Showing last 10 lines per container with errors..."
for container in $(docker ps -a --format '{{.Names}}' 2>/dev/null | head -20); do
  local logs
  logs=$(docker logs --tail 20 "$container" 2>&1 | grep -iE "error|fatal|exception|panic|critical" | tail -5)
  if [[ -n "$logs" ]]; then
    echo -e "\n  ${RED}=== $container ===${NC}"
    echo "$logs" | head -5 | sed 's/^/    /'
  fi
done

subsection "Docker daemon errors"
journalctl -u docker --since "1 hour ago" --no-pager 2>/dev/null | grep -iE "error|fail" | tail -10 | sed 's/^/  /' || \
  echo "  (journalctl not accessible — may need sudo)"

# ============================================================
# 7. Traefik Status
# ============================================================
section "7. Traefik Reverse Proxy"
if docker ps --format '{{.Names}}' | grep -q "^traefik$"; then
  echo "Traefik container: running"
  echo "Traefik version:"
  docker exec traefik traefik version 2>/dev/null | head -3 | sed 's/^/  /' || echo "  cannot get version"
  echo ""
  echo "Traefik HTTP routes:"
  curl -sf http://localhost:80/api/http/routers 2>/dev/null | \
    python3 -c "import sys,json; [print(f'  {r[\"name\"]}: {r[\"status\"]} → {r[\"service\"]}') for r in json.load(sys.stdin)]" 2>/dev/null || \
    echo "  (cannot query API — may need BASIC_AUTH)"
  echo ""
  echo "Traefik services:"
  curl -sf http://localhost:80/api/http/services 2>/dev/null | \
    python3 -c "import sys,json; [print(f'  {s[\"name\"]}: {s.get(\"serverStatus\",\"unknown\")}') for s in json.load(sys.stdin)]" 2>/dev/null || \
    echo "  (cannot query API)"
else
  echo -e "${RED}Traefik container not running${NC}"
fi

# ============================================================
# 8. Port Occupancy
# ============================================================
section "8. Port Occupancy (critical ports)"
for port in 53 80 443 2375 2376 3000 3001 8080 8096 8123 9000 9001 9090 1880 2586 3010 51820; do
  local info
  info=$(ss -tlnp 2>/dev/null | grep ":$port " || netstat -tlnp 2>/dev/null | grep ":$port " || echo "")
  if [[ -n "$info" ]]; then
    echo -e "  ${GREEN}:$port${NC} — $info"
  else
    echo -e "  ${YELLOW}:$port${NC} — free"
  fi
done

# ============================================================
# 9. Environment Variables
# ============================================================
section "9. Environment Setup"
echo "DOMAIN: ${DOMAIN:-${DOMAIN:-not set}}"
echo "TZ: ${TZ:-not set}"
echo "Required env vars check:"
for var in DOMAIN; do
  if [[ -n "${!var}" ]]; then
    echo -e "  ${GREEN}✓${NC} $var = ${!var}"
  else
    echo -e "  ${RED}✗${NC} $var is not set"
  fi
done

subsection "Docker daemon.json"
if [[ -f /etc/docker/daemon.json ]]; then
  echo "  /etc/docker/daemon.json:"
  cat /etc/docker/daemon.json | python3 -m json.tool 2>/dev/null | sed 's/^/    /' || cat /etc/docker/daemon.json | sed 's/^/    /'
else
  echo -e "  ${YELLOW}No custom /etc/docker/daemon.json${NC}"
fi

# ============================================================
# 10. Network Connectivity
# ============================================================
section "10. Network Connectivity"
echo "Internet:"
if curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://www.baidu.com" 2>/dev/null; then
  :
else
  curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://8.8.8.8" 2>/dev/null || echo "  No internet"
fi

echo "Docker Hub:"
curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://hub.docker.com" 2>/dev/null || echo -e "  ${RED}Unreachable${NC}"

echo "GitHub:"
curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://github.com" 2>/dev/null || echo -e "  ${RED}Unreachable${NC}"

echo "gcr.io:"
curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://gcr.io" 2>/dev/null || echo -e "  ${RED}Unreachable${NC}"

echo "ghcr.io:"
curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://ghcr.io" 2>/dev/null || echo -e "  ${RED}Unreachable${NC}"

echo "m.daocloud.io (CN mirror):"
curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" "https://m.daocloud.io" 2>/dev/null || echo -e "  ${RED}Unreachable${NC}"

# ============================================================
# 11. DNS Resolution
# ============================================================
section "11. DNS Resolution"
for domain in google.com github.com docker.com baidu.com m.daocloud.io; do
  local resolved
  resolved=$(dig +short "$domain" 2>/dev/null | head -1 || nslookup "$domain" 2>/dev/null | grep Address | tail -1 | awk '{print $NF}')
  if [[ -n "$resolved" ]]; then
    echo -e "  ${GREEN}✓${NC} $domain → $resolved"
  else
    echo -e "  ${RED}✗${NC} $domain: failed"
  fi
done

# ============================================================
# 12. Compose File Validation
# ============================================================
section "12. Compose File Validation"
for compose_file in $(find "$BASE_DIR/stacks" -name 'docker-compose*.yml' 2>/dev/null); do
  if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $(basename $(dirname "$compose_file")): valid"
  else
    echo -e "  ${RED}✗${NC} $compose_file: INVALID"
    docker compose -f "$compose_file" config 2>&1 | head -5 | sed 's/^/    /'
  fi
done

# ============================================================
# 13. Summary & Recommendations
# ============================================================
section "13. Summary & Recommendations"
echo ""
echo "Done. Review the sections above for issues."
echo ""
echo "Common fixes:"
echo "  • Run ./scripts/check-connectivity.sh for network diagnostics"
echo "  • Run sudo ./scripts/setup-cn-mirrors.sh for CN mirror setup"
echo "  • Run ./scripts/localize-images.sh --cn for CN image replacement"
echo "  • Run docker compose -f stacks/<name>/docker-compose.yml up -d to restart a stack"
echo "  • Run docker system prune -a to free disk space"
echo ""

if [[ -n "$OUTPUT_FILE" ]]; then
  echo -e "${GREEN}Full report saved to: $OUTPUT_FILE${NC}"
fi
