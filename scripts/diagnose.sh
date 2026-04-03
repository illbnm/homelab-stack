#!/usr/bin/env bash
# =============================================================================
# Diagnose — Collect system info and diagnostics for bug reports
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
OUTPUT_FILE="${1:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "  ${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "  ${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
log_fail()  { echo -e "  ${RED}[FAIL]${NC} $*"; }

write() { echo "$*" >> "$REPORT"; }
write_block() {
  local title="$1"
  write ""
  write "============================================================"
  write "  $title"
  write "============================================================"
  write ""
}

exec_cmd() {
  local label="$1"; shift
  write "--- $label ---"
  if [[ $# -eq 1 ]]; then
    $1 >> "$REPORT" 2>&1 || write "(command failed)"
  else
    "$@" >> "$REPORT" 2>&1 || write "(command failed)"
  fi
  write ""
}

REPORT="${OUTPUT_FILE:-/dev/stdout}"

if [[ -n "$OUTPUT_FILE" ]]; then
  REPORT="$OUTPUT_FILE"
  exec 1>"$REPORT" 2>&1
  echo "Writing diagnostic report to: $OUTPUT_FILE"
fi

write_block "System Information"
exec_cmd "Hostname & Date" hostname; date
exec_cmd "OS Release" cat /etc/os-release 2>/dev/null || uname -a
exec_cmd "Kernel" uname -r
exec_cmd "Uptime" uptime
exec_cmd "Load Average" cat /proc/loadavg

write_block "Memory"
exec_cmd "Free -h" free -h
exec_cmd "Meminfo" head -5 /proc/meminfo

write_block "Disk Space"
exec_cmd "Filesystem usage" df -h | grep -E '^/dev|Filesystem'
exec_cmd "Docker data size" du -sh /var/lib/docker 2>/dev/null || echo "N/A"

write_block "CPU"
exec_cmd "CPU Info" nproc
exec_cmd "CPU Model" cat /proc/cpuinfo | grep "model name" | head -1

write_block "Network"
exec_cmd "IP Addresses" ip addr show | grep -E 'inet ' | awk '{print $2}'
exec_cmd "DNS" cat /etc/resolv.conf | grep nameserver
exec_cmd "Gateway" ip route | grep default

write_block "Docker Version"
exec_cmd "docker version" docker version
exec_cmd "docker info (mirrors)" docker info 2>/dev/null | grep -A10 "Registry Mirrors" || echo "none"

write_block "Docker Daemon Config"
exec_cmd "daemon.json" cat /etc/docker/daemon.json 2>/dev/null || echo "not found"

write_block "Docker Network"
exec_cmd "docker network ls" docker network ls

write_block "Container Status"
exec_cmd "docker ps -a" docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

write_block "Unhealthy Containers"
docker ps -a --format "{{.Names}}:{{.Status}}" | grep -v "Up" | while IFS=: read -r name status; do
  write "  ✗ $name — $status"
done

write_block "Container Health Checks"
docker ps -a --format "{{.Names}}:{{.Status}}" | while IFS=: read -r name status; do
  health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
  write "  $name | $status | health=$health"
done

write_block "Docker Volumes"
exec_cmd "docker volume ls" docker volume ls

write_block "Recent Container Logs (last 20 lines each)"
for container in $(docker ps -aq 2>/dev/null); do
  name=$(docker inspect --format='{{.Name}}' "$container" 2>/dev/null | sed 's/^\///')
  write "--- $name ---"
  docker logs "$container" --tail 20 2>&1 | tail -20 >> "$REPORT" 2>&1
  write ""
done

write_block "Connectivity Tests"
exec_cmd "GitHub" curl -sf --connect-timeout 5 --max-time 10 https://github.com -o /dev/null -w "HTTP %{http_code} in %{time_total}s" || write "FAIL"
exec_cmd "Docker Hub" curl -sf --connect-timeout 5 --max-time 10 https://hub.docker.com -o /dev/null -w "HTTP %{http_code} in %{time_total}s" || write "FAIL"
exec_cmd "gcr.io" curl -sf --connect-timeout 5 --max-time 10 https://gcr.io/v2/ -o /dev/null -w "HTTP %{http_code} in %{time_total}s" || write "FAIL"
exec_cmd "ghcr.io" curl -sf --connect-timeout 5 --max-time 10 https://ghcr.io/v2/ -o /dev/null -w "HTTP %{http_code} in %{time_total}s" || write "FAIL"
exec_cmd "m.daocloud.io" curl -sf --connect-timeout 5 --max-time 10 https://m.daocloud.io/v2/ -o /dev/null -w "HTTP %{http_code} in %{time_total}s" || write "FAIL"

write_block "Installed Packages"
exec_cmd "docker-compose" docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "not found"
exec_cmd "docker-compose-plugin" docker compose version 2>/dev/null || echo "not found"
exec_cmd "docker-compose version" docker compose version 2>/dev/null || echo "N/A"

write_block "Stack Compose Files"
find "$SCRIPT_DIR/../stacks" -maxdepth 3 -name "docker-compose*.yml" -exec echo "  {}" \; 2>/dev/null

write_block "Relevant .env Files"
find "$SCRIPT_DIR/../stacks" -name ".env*" -exec echo "  {}" \; 2>/dev/null

write_block "Hosts File Entries (GitHub)"
grep -E "github|raw.githubusercontent" /etc/hosts 2>/dev/null || echo "no GitHub entries"

write_block "Firewall Status"
if command -v ufw &>/dev/null; then
  exec_cmd "ufw status" sudo ufw status
fi
if command -v firewalld &>/dev/null; then
  exec_cmd "firewalld" sudo firewall-cmd --list-all 2>/dev/null || echo "N/A"
fi

write_block "ShellCheck Results (critical scripts)"
for script in "$SCRIPT_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  name=$(basename "$script")
  result=$(shellcheck "$script" 2>/dev/null || true)
  if echo "$result" | grep -q "SC[0-9]"; then
    write "  ✗ $name — issues found"
    echo "$result" | grep "SC[0-9]" | head -5 | while read -r line; do
      write "    $line"
    done
  else
    write "  ✓ $name — no issues"
  fi
done

write_block "End of Diagnostic Report"
write "Generated: $(date)"
write "Script: $0"

if [[ -n "$OUTPUT_FILE" ]]; then
  echo ""
  log_ok "Report saved to: $OUTPUT_FILE"
  echo "Please attach this file when submitting a bug report."
fi
