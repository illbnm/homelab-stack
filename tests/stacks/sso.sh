#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
[[ -f .env ]] && { set -a; source .env; set +a; }

echo "  Containers:"
assert_container_running "authentik-server"
assert_container_running "authentik-worker"
assert_container_running "authentik-db"
assert_container_running "authentik-redis"
assert_container_healthy "authentik-db"
assert_container_healthy "authentik-redis"

echo "  Authentik health:"
skip_if_not_running "authentik-server" && {
  health=$(curl -sk http://localhost:9000/-/health/live/ 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  assert_eq "Authentik health" "ok" "$health"
}

[[ -n "${DOMAIN:-}" ]] && \
  assert_http_ok "Authentik UI" "https://auth.${DOMAIN}" || \
  echo "    ⏭ DOMAIN not set"
