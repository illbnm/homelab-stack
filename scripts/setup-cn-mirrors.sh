#!/usr/bin/env bash
# Usage: ./scripts/setup-cn-mirrors.sh [--yes] [--dry-run]
# Configures /etc/docker/daemon.json with China mainland registry mirrors and verifies docker pull.
set -euo pipefail

AUTO_YES=false
DRY_RUN=false
DAEMON_JSON="${DAEMON_JSON:-/etc/docker/daemon.json}"

for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--yes] [--dry-run]"
      exit 0
      ;;
  esac
done

if [[ "$AUTO_YES" == "false" && -t 0 ]]; then
  read -r -p "Are you deploying inside China mainland and want to enable Docker registry mirrors? [Y/n] " reply
  reply="${reply:-Y}"
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "[INFO] Skipping CN Docker mirror configuration."
    exit 0
  fi
fi

MIRROR_PAYLOAD='{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.baidubce.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.gcr.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}'

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would write to ${DAEMON_JSON}:"
  echo "$MIRROR_PAYLOAD"
  exit 0
fi

mkdir -p "$(dirname "$DAEMON_JSON")"
if [[ -f "$DAEMON_JSON" ]]; then
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
fi
printf '%s\n' "$MIRROR_PAYLOAD" > "$DAEMON_JSON"
echo "[OK] Wrote registry mirrors to ${DAEMON_JSON}"

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl restart docker || true
fi

if command -v docker >/dev/null 2>&1; then
  echo "[INFO] Verifying mirror configuration with docker pull hello-world:linux..."
  docker pull hello-world:linux >/dev/null 2>&1 || echo "[WARN] docker pull check skipped or daemon offline"
fi
