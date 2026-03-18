#!/usr/bin/env bash
# =============================================================================
# Diagnose — 一键诊断工具
# Collects system info, container status, logs, and network tests.
# Outputs diagnostic report for troubleshooting / issue submission.
# Usage: ./scripts/diagnose.sh [--output diagnose-report.txt]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Parse args
OUTPUT_FILE=""
for arg in "$@"; do
  case "$arg" in
    --output) shift; OUTPUT_FILE="$1" ;;
    -h|--help)
      echo "Usage: $0 [--output <file>]"
      echo "  --output  Write report to file (default: stdout)"
      exit 0
      ;;
  esac
done

# Output handler
report() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$@" >> "$OUTPUT_FILE"
  fi
  echo "$@"
}

section() {
  report ""
  report "═══════════════════════════════════════════════════════════════"
  report "  $1"
  report "═══════════════════════════════════════════════════════════════"
}

# Clear output file if specified
[[ -n "$OUTPUT_FILE" ]] && : > "$OUTPUT_FILE"

report "HomeLab Stack — Diagnostic Report"
report "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
report "Host: $(hostname)"

# ─── 1. System Information ──────────────────────────────────────────────────
section "System Information"
report ""
report "  OS:       $(uname -s) $(uname -r)"
if [[ -f /etc/os-release ]]; then
  report "  Distro:   $(. /etc/os-release && echo "$PRETTY_NAME")"
fi
report "  Arch:     $(uname -m)"
report "  Hostname: $(hostname)"
report "  Uptime:   $(uptime 2>/dev/null | sed 's/.*up //' | sed 's/,.*//')"

# Memory
if command -v free &>/dev/null; then
  total_mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')
  used_mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}')
  report "  Memory:   ${used_mem} / ${total_mem}"
elif [[ "$(uname)" == "Darwin" ]]; then
  total_mem=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
  report "  Memory:   ${total_mem}GB total"
fi

# Disk
report "  Disk:"
df -h / 2>/dev/null | tail -1 | awk '{printf "    /: %s used of %s (%s)\n", $3, $2, $5}'
if [[ -d /data ]]; then
  df -h /data 2>/dev/null | tail -1 | awk '{printf "    /data: %s used of %s (%s)\n", $3, $2, $5}'
fi

# ─── 2. Docker Information ──────────────────────────────────────────────────
section "Docker"
report ""
if command -v docker &>/dev/null; then
  report "  Docker version:"
  docker version --format '    Client: {{.Client.Version}} | Server: {{.Server.Version}}' 2>/dev/null || report "    (server not running?)"
  report ""

  # Docker Compose version
  if docker compose version &>/dev/null; then
    report "  Compose: $(docker compose version --short 2>/dev/null)"
  elif command -v docker-compose &>/dev/null; then
    report "  Compose: $(docker-compose version --short 2>/dev/null) (v1 — UPGRADE RECOMMENDED)"
  else
    report "  Compose: NOT FOUND"
  fi

  # Docker info
  report ""
  report "  Docker root dir: $(docker info --format '{{.DockerRootDir}}' 2>/dev/null)"
  report "  Storage driver:  $(docker info --format '{{.Driver}}' 2>/dev/null)"
  report "  Registry mirrors:"
  docker info 2>/dev/null | grep -A 5 "Registry Mirrors:" | sed 's/^/    /' || report "    (none)"
else
  report "  Docker: NOT INSTALLED"
fi

# ─── 3. Container Status ────────────────────────────────────────────────────
section "Container Status"
report ""
if command -v docker &>/dev/null; then
  report "  $(docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | head -50)"

  # Count by state
  running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
  total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
  report ""
  report "  Running: $running / $total"

  # Unhealthy containers
  unhealthy=$(docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null)
  if [[ -n "$unhealthy" ]]; then
    report ""
    report "  ⚠ Unhealthy containers:"
    echo "$unhealthy" | while read -r c; do
      report "    - $c"
    done
  fi
fi

# ─── 4. Recent Error Logs ───────────────────────────────────────────────────
section "Recent Error Logs"
report ""
if command -v docker &>/dev/null; then
  for container in $(docker ps --format '{{.Names}}' 2>/dev/null | head -20); do
    errors=$(docker logs --tail 20 "$container" 2>&1 | grep -i "error\|fatal\|panic\|exception" | head -5)
    if [[ -n "$errors" ]]; then
      report "  ─── $container ───"
      echo "$errors" | while read -r line; do
        report "    $line"
      done
      report ""
    fi
  done
  report "  (showing last 20 lines per container, filtered for errors)"
fi

# ─── 5. Network Connectivity ────────────────────────────────────────────────
section "Network Connectivity"
report ""
for host in "hub.docker.com" "github.com" "gcr.io" "ghcr.io"; do
  if curl -sf --connect-timeout 5 --max-time 10 "https://$host" >/dev/null 2>&1; then
    report "  [OK]   $host"
  else
    report "  [FAIL] $host"
  fi
done

# ─── 6. Port Usage ──────────────────────────────────────────────────────────
section "Port Usage (common ports)"
report ""
for port in 53 80 443 3000 8080 9090; do
  if command -v ss &>/dev/null; then
    pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -v "State" | head -1)
  elif command -v lsof &>/dev/null; then
    pid=$(lsof -i ":$port" -sTCP:LISTEN 2>/dev/null | tail -1)
  else
    pid=""
  fi
  if [[ -n "$pid" ]]; then
    report "  Port $port: IN USE"
  else
    report "  Port $port: available"
  fi
done

# ─── 7. Config Validation ───────────────────────────────────────────────────
section "Configuration Files"
report ""
for stack_dir in "$ROOT_DIR"/stacks/*/; do
  stack_name=$(basename "$stack_dir")
  compose="$stack_dir/docker-compose.yml"
  env_file="$stack_dir/.env"

  if [[ -f "$compose" ]]; then
    # Validate compose syntax
    if docker compose -f "$compose" config >/dev/null 2>&1; then
      report "  [OK]   stacks/$stack_name/docker-compose.yml"
    else
      report "  [FAIL] stacks/$stack_name/docker-compose.yml — syntax error"
    fi
  fi

  if [[ ! -f "$env_file" ]] && [[ -f "$stack_dir/.env.example" ]]; then
    report "  [WARN] stacks/$stack_name/.env missing (copy from .env.example)"
  fi
done

# ─── Summary ────────────────────────────────────────────────────────────────
section "Summary"
report ""
report "  Report generated at: $(date)"
if [[ -n "$OUTPUT_FILE" ]]; then
  report "  Saved to: $OUTPUT_FILE"
  report ""
  report "  Attach this file when submitting a GitHub issue."
fi
report ""
report "  For help: https://github.com/illbnm/homelab-stack/issues"
