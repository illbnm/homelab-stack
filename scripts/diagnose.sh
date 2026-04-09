#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Diagnostic Report Generator
# Collects system info for issue reporting.
#
# Usage: ./scripts/diagnose.sh [--output FILE] [--upload]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

OUTPUT_FILE="${ROOT_DIR}/diagnose-report.txt"
UPLOAD=false

for arg in "$@"; do
  case "$arg" in
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --upload) UPLOAD=true ;;
    --help)   echo "Usage: $0 [--output FILE] [--upload]"; exit 0 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

report() {
  echo "$@" | tee -a "$OUTPUT_FILE"
}

report_header() {
  report ""
  report "================================================================"
  report "  $1"
  report "================================================================"
}

# Initialize report
echo "HomeLab Stack — Diagnostic Report" > "$OUTPUT_FILE"
report "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
report "Hostname: $(hostname)"

# ---------------------------------------------------------------------------
# System Information
# ---------------------------------------------------------------------------
report_header "System Information"
report "OS: $(uname -s)"
report "Kernel: $(uname -r)"
report "Architecture: $(uname -m)"
if [ -f /etc/os-release ]; then
  report "Distribution: $(grep ^PRETTY_NAME= /etc/os-release | cut -d'"' -f2)"
fi
report "Uptime: $(uptime -p 2>/dev/null || uptime)"
report "CPU: $(nproc) cores"
mem_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")
mem_avail=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "unknown")
report "Memory: Total ${mem_total}, Available ${mem_avail}"
disk_root=$(df -h / 2>/dev/null | awk 'NR==2 {print "$4 free of $2 ($5 used)"}' || echo "unknown")
report "Disk (/): $(df -h / 2>/dev/null | awk 'NR==2 {print $4, "free of", $2, "(" $5, "used)"}')"
report "Load Average: $(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo 'unknown')"

# ---------------------------------------------------------------------------
# Docker Information
# ---------------------------------------------------------------------------
report_header "Docker Information"
if command -v docker &>/dev/null; then
  report "Docker Version: $(docker --version 2>/dev/null)"
  report "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'not found')"
  report "Docker Root: $(docker info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $NF}' || echo 'unknown')"
  report "Storage Driver: $(docker info 2>/dev/null | grep 'Storage Driver' | awk '{print $NF}' || echo 'unknown')"
  report "Containers: $(docker ps -q 2>/dev/null | wc -l) running / $(docker ps -aq 2>/dev/null | wc -l) total"
  report "Images: $(docker images -q 2>/dev/null | wc -l)"

  # Mirror configuration
  if [ -f /etc/docker/daemon.json ]; then
    report "Registry Mirrors: $(grep -o '"registry-mirrors"[^}]*}' /etc/docker/daemon.json 2>/dev/null | head -1 || echo 'none')"
  fi
else
  report "Docker: NOT INSTALLED"
fi

# ---------------------------------------------------------------------------
# Container Status
# ---------------------------------------------------------------------------
report_header "Container Status"
if command -v docker &>/dev/null; then
  report "$(docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | head -50)" || report "Could not list containers"
fi

# ---------------------------------------------------------------------------
# Recent Container Errors
# ---------------------------------------------------------------------------
report_header "Recent Container Errors (last 50 lines per container)"
if command -v docker &>/dev/null; then
  for container in $(docker ps --format '{{.Names}}' 2>/dev/null | head -20); do
    errors=$(docker logs --tail 50 "$container" 2>&1 | grep -iE "error|fatal|panic|fail|refused|timeout" | tail -5 || true)
    if [ -n "$errors" ]; then
      report ""
      report "--- $container ---"
      report "$errors"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Network Connectivity
# ---------------------------------------------------------------------------
report_header "Network Connectivity"
if [ -f "${SCRIPT_DIR}/check-connectivity.sh" ]; then
  report "$(bash "${SCRIPT_DIR}/check-connectivity.sh" 2>&1 || true)"
else
  for host in hub.docker.com github.com ghcr.io gcr.io; do
    if timeout 5 bash -c "echo >/dev/tcp/$host/443" 2>/dev/null; then
      report "[OK]   $host:443"
    else
      report "[FAIL] $host:443"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Configuration Validation
# ---------------------------------------------------------------------------
report_header "Configuration Validation"
if command -v docker &>/dev/null; then
  for compose_file in $(find "$ROOT_DIR/stacks" -name "docker-compose.yml" 2>/dev/null | sort); do
    rel=$(realpath --relative-to="$ROOT_DIR" "$compose_file")
    if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
      report "[OK]   $rel"
    else
      report "[FAIL] $rel — $(docker compose -f "$compose_file" config 2>&1 | head -3)"
    fi
  done
fi

# Check .env exists
if [ -f "$ROOT_DIR/.env" ]; then
  report "[OK]   .env exists"
  # Check for empty required vars
  empty_vars=$(grep -E '^[A-Z_]+=$\|^[A-Z_]+=\s*#' "$ROOT_DIR/.env" 2>/dev/null | grep -v '^#' || true)
  if [ -n "$empty_vars" ]; then
    report "[WARN] Empty .env variables:"
    report "$empty_vars"
  fi
else
  report "[FAIL] .env not found — run: cp .env.example .env"
fi

# ---------------------------------------------------------------------------
# Port Conflicts
# ---------------------------------------------------------------------------
report_header "Port Usage"
for port in 53 80 443 3000 3001 3100 3200 5432 6379 8080 9000 9090 9093 9443; do
  listener=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 || true)
  if [ -n "$listener" ]; then
    report "[USED] :$port — $(echo "$listener" | awk '{print $NF}')"
  else
    report "[FREE] :$port"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
report_header "Summary"
report ""
report "Report saved to: $OUTPUT_FILE"
report ""
report "To share this report, paste the contents of $OUTPUT_FILE"
report "or attach the file to your GitHub issue."

echo
echo -e "${GREEN}[OK]${NC} Diagnostic report saved to $OUTPUT_FILE"
echo
echo "Attach this file when creating an issue:"
echo "  https://github.com/illbnm/homelab-stack/issues/new"
