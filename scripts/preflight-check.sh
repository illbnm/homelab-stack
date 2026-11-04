#!/usr/bin/env bash
set -euo pipefail

echo "[Preflight] Checking Docker & Compose environment..."
command -v docker >/dev/null 2>&1 || { echo "Error: docker not installed" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Error: docker compose plugin missing" >&2; exit 1; }

FREE_GB=$(df -BG . | awk 'NR==2 {gsub("G","",$4); print $4}')
if [ "${FREE_GB:-0}" -lt 10 ]; then
  echo "Warning: Less than 10GB free disk space (${FREE_GB}GB available)" >&2
fi
echo "[Preflight] All environment checks passed (${FREE_GB}GB free)."
