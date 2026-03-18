#!/usr/bin/env bash
# =============================================================================
# Diagnose — 一键诊断 HomeLab Stack 环境
# 输出到终端 + diagnose-report.txt
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
REPORT="$PROJECT_DIR/diagnose-report.txt"

exec > >(tee "$REPORT") 2>&1

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# ---------------------------------------------------------------------------
echo "HomeLab Stack Diagnostic Report"
echo "Generated: $(timestamp)"
echo "Host: $(hostname)"
echo "================================================================"
# ---------------------------------------------------------------------------

section "1. System Info"
echo "  OS:           $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "  Kernel:       $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Uptime:       $(uptime -p 2>/dev/null || uptime)"
echo "  Memory:       $(free -h 2>/dev/null | awk '/Mem:/{print $2 " total, " $3 " used, " $4 " free"}')"
echo "  CPU:          $(nproc) cores"
echo "  Disk (/):     $(df -h / | awk 'NR==2{print $3 " used, " $4 " free (" $5 " capacity)"}')"

section "2. Docker Info"
if command -v docker &>/dev/null; then
  echo "  Docker:       $(docker --version 2>/dev/null || echo 'unknown')"
  if docker info &>/dev/null; then
    echo "  Daemon:       running"
    echo "  Storage:      $(docker info 2>/dev/null | grep 'Storage Driver' | awk '{print $3}')"
    echo "  Containers:   $(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l) total, $(docker ps --format '{{.Names}}' 2>/dev/null | wc -l) running"
  else
    echo -e "  ${RED}Daemon:       NOT running${NC}"
  fi
  echo "  Compose:      $(docker compose version --short 2>/dev/null || echo 'not found (v2)')"
  if command -v docker-compose &>/dev/null; then
    echo -e "  ${YELLOW}WARNING: docker-compose v1 detected — consider upgrading to v2 plugin${NC}"
  fi
else
  echo -e "  ${RED}Docker: NOT installed${NC}"
fi

section "3. Container Status"
if command -v docker &>/dev/null && docker info &>/dev/null; then
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -30
  echo ""

  # Check for unhealthy/restarting
  problem_containers=$(docker ps -a --filter "status=exited" --filter "status=dead" --filter "health=unhealthy" --format "{{.Names}} ({{.Status}})" 2>/dev/null)
  if [[ -n "$problem_containers" ]]; then
    echo -e "  ${YELLOW}Problem containers:${NC}"
    echo "$problem_containers"
  fi
else
  echo "  Docker not available"
fi

section "4. Recent Error Logs (last 100 lines)"
if command -v docker &>/dev/null; then
  docker logs --since 1h --tail 100 2>&1 | grep -iE 'error|fatal|panic|warn' | tail -30 || echo "  No recent errors"
  echo ""
  # Per-container errors
  for c in $(docker ps --format '{{.Names}}' 2>/dev/null | head -10); do
    errs=$(docker logs --since 1h "$c" 2>&1 | grep -ciE 'error|fatal' || true)
    if [[ "$errs" -gt 0 ]]; then
      echo -e "  ${YELLOW}$c${NC}: $errs error(s) in last hour"
    fi
  done
else
  echo "  Docker not available"
fi

section "5. Network Connectivity"
if command -v curl &>/dev/null; then
  for target in "hub.docker.com:Docker Hub" "github.com:GitHub" "gcr.io:gcr.io" "ghcr.io:ghcr.io"; do
    host="${target%%:*}"; name="${target##*:}"
    if curl -sf --connect-timeout 5 --max-time 10 "https://$host" >/dev/null 2>&1; then
      echo -e "  ${GREEN}✓${NC} $name ($host)"
    else
      echo -e "  ${RED}✗${NC} $name ($host) — unreachable"
    fi
  done
else
  echo "  curl not available"
fi

section "6. Port Conflicts"
for port in 53 80 443 3000 3080 8080 8443 51820 9000; do
  if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
    echo -e "  ${YELLOW}⚠ Port $port in use${NC}"
  fi
done
echo "  (No output above = all clear)"

section "7. Config File Validation"
env_path="$PROJECT_DIR/.env"
if [[ -f "$env_path" ]]; then
  required_vars=(DOMAIN ACME_EMAIL TZ)
  missing=0
  for var in "${required_vars[@]}"; do
    val=$(grep -E "^${var}=" "$env_path" | cut -d= -f2- | tr -d '"' || true)
    if [[ -z "$val" ]]; then
      echo -e "  ${RED}✗${NC} $var not set"
      ((missing++))
    fi
  done
  [[ $missing -eq 0 ]] && echo -e "  ${GREEN}✓${NC} .env: required variables present"
else
  echo -e "  ${RED}✗${NC} .env not found"
fi

# Validate compose files
for f in "$PROJECT_DIR"/stacks/*/docker-compose*.yml "$PROJECT_DIR"/docker-compose*.yml; do
  [[ -f "$f" ]] || continue
  if docker compose -f "$f" config --quiet 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} ${f#$PROJECT_DIR/}"
  else
    echo -e "  ${RED}✗${NC} ${f#$PROJECT_DIR/} — validation failed"
  fi
done

section "8. Disk Space"
df -h / /var/lib/docker 2>/dev/null | awk 'NR<=2{print "  " $0}'
docker system df 2>/dev/null | head -6 || echo "  (Docker not available)"

echo -e "\n================================================================"
echo "Report saved to: $REPORT"
echo "================================================================\n"
