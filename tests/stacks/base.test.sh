#!/usr/bin/env bash
# =============================================================================
# Base Infrastructure Tests — Traefik + Portainer + Watchtower
# =============================================================================

# Container health
assert_container_running traefik
assert_container_healthy traefik 30
assert_container_running portainer
assert_container_healthy portainer 30
assert_container_running watchtower

# Traefik HTTP endpoints
assert_http_200 "http://localhost:8080/api/version" 10
assert_http_200 "http://localhost:9000/api/status" 10

# Traefik ping
test_start "Traefik ping"
traefik_ping=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:8080/ping" 2>/dev/null || echo "000")
if [[ "$traefik_ping" =~ ^2 ]]; then
  test_pass
else
  test_fail "Traefik ping returned HTTP $traefik_ping"
fi

# Verify proxy network exists
test_start "Docker proxy network exists"
if docker network inspect proxy >/dev/null 2>&1; then
  test_pass
else
  test_fail "Docker 'proxy' network not found"
fi

# Verify Traefik is listening on ports 80/443
test_start "Traefik listening on port 80"
if ss -tln 2>/dev/null | grep -q ':80 ' || netstat -tln 2>/dev/null | grep -q ':80 '; then
  test_pass
else
  test_fail "Port 80 not listening"
fi

test_start "Traefik listening on port 443"
if ss -tln 2>/dev/null | grep -q ':443 ' || netstat -tln 2>/dev/null | grep -q ':443 '; then
  test_pass
else
  test_fail "Port 443 not listening"
fi

# Watchtower label check
test_start "Watchtower has schedule label"
wl=$(docker inspect --format '{{index .Config.Labels "com.centurylinklabs.watchtower.enable"}}' watchtower 2>/dev/null || echo "")
assert_eq "$wl" "true" "Watchtower enable label not set"
