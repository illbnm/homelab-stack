#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — System Diagnostics
# Collects system info for bug reports.
# Usage: ./diagnose.sh [--output diagnose-report.txt]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
OUTPUT="${1:---output}"
OUTPUT_FILE="${2:-diagnose-report.txt}"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'

section() { echo -e "\n${CYAN}═══ $1 ═══${RESET}"; }

{
  echo "HomeLab Stack — Diagnostic Report"
  echo "Generated: $(date)"
  echo "========================================"
  
  section "System"
  echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || uname -a)"
  echo "Kernel: $(uname -r)"
  echo "Arch: $(uname -m)"
  echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
  
  section "Resources"
  echo "Memory:"
  free -h 2>/dev/null || echo "  free not available"
  echo "Disk:"
  df -h / /var/lib/docker 2>/dev/null | grep -v tmpfs || echo "  df failed"
  echo "CPU: $(nproc) cores | $(cat /proc/cpuinfo 2>/dev/null | grep 'model name' | head -1 | cut -d: -f2 | xargs || echo 'unknown')"
  
  section "Docker"
  echo "Version: $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
  echo "Compose: $(docker compose version 2>/dev/null || echo 'NOT INSTALLED')"
  echo "Daemon: $(docker info --format '{{.ServerVersion}}' 2>/dev/null || echo 'NOT RUNNING')"
  echo "Running containers: $(docker ps -q 2>/dev/null | wc -l)"
  
  section "Container Status"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "  Docker not running"
  
  section "Unhealthy Containers"
  for c in $(docker ps -q 2>/dev/null); do
    name=$(docker inspect "$c" --format '{{.Name}}' 2>/dev/null | sed 's|^/||')
    status=$(docker inspect "$c" --format '{{.State.Health.Status}}' 2>/dev/null || echo "N/A")
    if [ "$status" != "healthy" ] && [ "$status" != "N/A" ]; then
      echo "  $name: $status"
      docker logs --tail 20 "$c" 2>/dev/null | sed 's/^/    /'
      echo ""
    fi
  done
  
  section "Recent Docker Errors"
  journalctl -u docker --since "1 hour ago" -p err --no-pager 2>/dev/null | tail -20 || echo "  journalctl not available"
  
  section "Port Usage"
  ss -tuln 2>/dev/null | grep LISTEN | head -20 || netstat -tuln 2>/dev/null | head -20 || echo "  Network tools not available"
  
  section "Config File Validation"
  for file in "$ROOT_DIR/config"/*/*.yml "$ROOT_DIR/config"/*/*.yaml; do
    [ -f "$file" ] || continue
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
      echo "  ✓ $file"
    else
      echo "  ✗ $file — INVALID YAML"
    fi
  done
  
  echo ""
  echo "========================================"
  echo "Report complete"
} | tee "${OUTPUT_FILE:-/dev/stdout}"

if [ -n "${OUTPUT_FILE:-}" ] && [ "$OUTPUT_FILE" != "/dev/stdout" ]; then
  echo ""
  echo -e "${GREEN}Report saved to: $OUTPUT_FILE${RESET}"
fi
