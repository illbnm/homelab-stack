#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$ROOT_DIR/.venv-uptime-kuma"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

: "${DOMAIN:?DOMAIN is required in environment or .env}"
: "${UPTIME_KUMA_USERNAME:?UPTIME_KUMA_USERNAME is required}"
: "${UPTIME_KUMA_PASSWORD:?UPTIME_KUMA_PASSWORD is required}"

if [[ ! -d "$VENV_DIR" ]]; then
  echo "[INFO] Creating local virtualenv: $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if ! python -c 'import uptime_kuma_api' >/dev/null 2>&1; then
  echo "[INFO] Installing dependency uptime-kuma-api in virtualenv..."
  python -m pip install --upgrade pip
  python -m pip install uptime-kuma-api
fi

exec python "$SCRIPT_DIR/uptime-kuma-setup.py"
