#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
[[ -f .env ]] && { set -a; source .env; set +a; }

echo "  Containers:"
assert_container_running "traefik"
assert_container_running "portainer"
assert_container_running "watchtower"
assert_container_healthy "portainer"

echo "  Network:"
docker network inspect proxy &>/dev/null && \
  echo "    ✅ proxy network exists" && ((PASS++)) || \
  { echo "    ❌ proxy network missing"; ((FAIL++)); }

echo "  HTTP endpoints:"
[[ -n "${DOMAIN:-}" ]] && {
  assert_http_ok "Traefik dashboard" "https://traefik.${DOMAIN}"
  assert_http_ok "Portainer UI" "https://portainer.${DOMAIN}"
} || echo "    ⏭ DOMAIN not set — skipping URL checks"
