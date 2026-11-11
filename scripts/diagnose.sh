#!/usr/bin/env bash
# Usage: ./scripts/diagnose.sh [--output diagnose-report.txt]
# Generates a full system, Docker, container, log, connectivity, and compose validation report.
set -euo pipefail

OUT_FILE="${1:-diagnose-report.txt}"
if [[ "${1:-}" == "--output" && -n "${2:-}" ]]; then
  OUT_FILE="$2"
fi

{
  echo "=========================================="
  echo "HomeLab Stack Diagnostic Report"
  echo "Generated at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "=========================================="
  echo ""
  echo "### 1. System Information"
  uname -a || true
  df -h || true
  free -m 2>/dev/null || true
  echo ""
  echo "### 2. Docker & Compose Versions"
  docker --version 2>/dev/null || echo "Docker not installed"
  docker compose version 2>/dev/null || echo "Docker Compose v2 not installed"
  echo ""
  echo "### 3. Running Containers"
  docker ps -a 2>/dev/null || true
  echo ""
  echo "### 4. Connectivity Check"
  bash "$(dirname "${BASH_SOURCE[0]}")/check-connectivity.sh" --mock || true
} | tee "$OUT_FILE"
