#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Diagnose tool
# =============================================================================
set -e

REPORT_FILE="diagnose-report.txt"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Generating diagnosis report... Please wait."

{
  echo "========================================"
  echo " HomeLab Stack Diagnostic Report"
  echo " Date: $(date)"
  echo "========================================"
  echo ""

  echo ">>> System Information"
  echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"' || uname -a)"
  echo "Kernel: $(uname -r)"
  echo "Memory: $(free -m | awk 'NR==2{printf "%.2fGB / %.2fGB\n", $3/1024, $2/1024}')"
  echo "Disk:"
  df -h /
  echo ""

  echo ">>> Docker Information"
  docker version || echo "Docker not accessible."
  echo ""

  echo ">>> Container Status"
  docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || echo "Unable to list containers."
  echo ""

  echo ">>> Recent Error Logs (last 50 lines of docker events / container errors)"
  for cid in $(docker ps -a --filter "status=exited" -q); do
    name=$(docker inspect --format='{{.Name}}' "$cid" | sed 's/^\///')
    echo "--- Logs for exited container: $name ---"
    docker logs --tail 20 "$cid" 2>&1 || true
  done
  echo ""

  echo ">>> Network Connectivity"
  if [ -x "$BASE_DIR/scripts/check-connectivity.sh" ]; then
    "$BASE_DIR/scripts/check-connectivity.sh" || true
  else
    bash "$BASE_DIR/scripts/check-connectivity.sh" || true
  fi
  echo ""

  echo ">>> Configuration Check"
  if [ -f "$BASE_DIR/.env" ]; then
    echo ".env file exists."
  else
    echo ".env file MISSING."
  fi
  if [ -f "$BASE_DIR/config/traefik/traefik.yml" ]; then
    echo "traefik.yml exists."
  else
    echo "traefik.yml MISSING."
  fi
  echo "========================================"
} > "$REPORT_FILE"

echo "Report generated at $REPORT_FILE."
cat "$REPORT_FILE"
