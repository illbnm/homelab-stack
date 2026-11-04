#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"
if [ ! -f "$ENV_FILE" ]; then
  PG_PASS="$(openssl rand -hex 24)"
  SECRET_KEY="$(openssl rand -hex 32)"
  cat > "$ENV_FILE" <<EOF
PG_USER=authentik
PG_DB=authentik
PG_PASS=${PG_PASS}
AUTHENTIK_SECRET_KEY=${SECRET_KEY}
AUTHENTIK_PORT_HTTP=9000
AUTHENTIK_PORT_HTTPS=9443
EOF
  echo "[SSO] Generated $ENV_FILE with randomized secrets."
fi
