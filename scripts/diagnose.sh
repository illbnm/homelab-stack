#!/usr/bin/env bash
# =============================================================================
# Diagnose — 一键诊断报告
# Collects system info, container status, recent errors, and connectivity
# results into a report for issue submissions.
#
# Usage:
#   ./scripts/diagnose.sh              # Print to stdout
#   ./scripts/diagnose.sh --file       # Write to diagnose-report.txt
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
REPORT_FILE="$PROJECT_DIR/diagnose-report.txt"
OUTPUT_FILE=""

if [[ "${1:-}" == "--file" ]]; then
  OUTPUT_FILE="$REPORT_FILE"
fi

# ---------------------------------------------------------------------------
# Output helper — write to file or stdout
# ---------------------------------------------------------------------------
out() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$@" >> "$OUTPUT_FILE"
  else
    echo "$@"
  fi
}

# Clear report file if writing to file
if [[ -n "$OUTPUT_FILE" ]]; then
  true > "$OUTPUT_FILE"
fi

out "=============================================="
out "HomeLab Stack — Diagnostic Report"
out "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
out "=============================================="
out ""

# ---------------------------------------------------------------------------
# Section 1: System Information
# ---------------------------------------------------------------------------
out "=== System Information ==="
out "Hostname:     $(hostname 2>/dev/null || echo 'unknown')"
out "OS:           $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)"
out "Kernel:       $(uname -r)"
out "Architecture: $(uname -m)"
out "CPU cores:    $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')"

# Memory
if command -v free &>/dev/null; then
  mem_total=$(free -h | awk '/^Mem:/ {print $2}')
  mem_used=$(free -h | awk '/^Mem:/ {print $3}')
  mem_avail=$(free -h | awk '/^Mem:/ {print $7}')
  out "Memory:       ${mem_used} used / ${mem_total} total (${mem_avail} available)"
else
  out "Memory:       (free command not available)"
fi

# Disk
disk_info=$(df -h / | awk 'NR==2 {printf "%s used / %s total (%s available, %s used)", $3, $2, $4, $5}')
out "Disk (/):     $disk_info"
out ""

# ---------------------------------------------------------------------------
# Section 2: Docker Information
# ---------------------------------------------------------------------------
out "=== Docker Information ==="
if command -v docker &>/dev/null; then
  out "Docker:       $(docker --version 2>/dev/null || echo 'error getting version')"
  out "Compose:      $(docker compose version 2>/dev/null || echo 'not available')"
  if docker info &>/dev/null; then
    out "Daemon:       running"
    out "Storage:      $(docker info --format '{{.Driver}}' 2>/dev/null || echo 'unknown')"
    out "Images:       $(docker images -q 2>/dev/null | wc -l) images"
    out "Containers:   $(docker ps -aq 2>/dev/null | wc -l) total, $(docker ps -q 2>/dev/null | wc -l) running"
  else
    out "Daemon:       NOT RUNNING"
  fi
else
  out "Docker:       NOT INSTALLED"
fi
out ""

# ---------------------------------------------------------------------------
# Section 3: Container Status
# ---------------------------------------------------------------------------
out "=== Container Status ==="
if docker info &>/dev/null; then
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" 2>/dev/null | while IFS= read -r line; do
    out "$line"
  done
else
  out "(Docker daemon not running)"
fi
out ""

# ---------------------------------------------------------------------------
# Section 4: Recent Error Logs (last 30 min)
# ---------------------------------------------------------------------------
out "=== Recent Error Logs (containers with errors) ==="
if docker info &>/dev/null; then
  containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null)
  found_errors=false
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    errors=$(docker logs --since 30m "$container" 2>&1 | grep -iE '(error|fatal|panic|exception|fail)' | tail -5)
    if [[ -n "$errors" ]]; then
      found_errors=true
      out "--- $container ---"
      out "$errors"
      out ""
    fi
  done <<< "$containers"
  if [[ "$found_errors" == "false" ]]; then
    out "(No errors found in the last 30 minutes)"
  fi
else
  out "(Docker daemon not running)"
fi
out ""

# ---------------------------------------------------------------------------
# Section 5: Network Connectivity
# ---------------------------------------------------------------------------
out "=== Network Connectivity ==="
for host in hub.docker.com github.com gcr.io ghcr.io; do
  start=$(date +%s%N)
  if curl -sf --connect-timeout 5 --max-time 10 -o /dev/null "https://$host" 2>/dev/null; then
    end=$(date +%s%N)
    ms=$(( (end - start) / 1000000 ))
    out "[OK]   $host — ${ms}ms"
  else
    out "[FAIL] $host — unreachable"
  fi
done
out ""

# ---------------------------------------------------------------------------
# Section 6: Port Usage
# ---------------------------------------------------------------------------
out "=== Port Usage (80, 443, 3000, 8080, 9090) ==="
for port in 80 443 3000 8080 9090; do
  proc=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 || true)
  if [[ -n "$proc" ]]; then
    out "Port $port: IN USE — $proc"
  else
    out "Port $port: available"
  fi
done
out ""

# ---------------------------------------------------------------------------
# Section 7: Config File Validation
# ---------------------------------------------------------------------------
out "=== Config File Validation ==="
config_files=(
  "config/traefik/traefik.yml"
  "config/prometheus/prometheus.yml"
  "config/alertmanager/alertmanager.yml"
  "config/loki/loki-config.yml"
  "config/grafana/grafana.ini"
)
for cf in "${config_files[@]}"; do
  full_path="$PROJECT_DIR/$cf"
  if [[ -f "$full_path" ]]; then
    out "[OK]   $cf exists ($(wc -l < "$full_path") lines)"
  else
    out "[MISS] $cf not found"
  fi
done
out ""

# ---------------------------------------------------------------------------
# Section 8: Docker Networks
# ---------------------------------------------------------------------------
out "=== Docker Networks ==="
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null | while IFS= read -r line; do
  out "$line"
done
out ""

# ---------------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------------
out "=============================================="
out "End of diagnostic report"
out "=============================================="

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "Diagnostic report written to: $OUTPUT_FILE"
  echo "Attach this file when submitting an issue."
fi
