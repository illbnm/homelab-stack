#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
[[ -f .env ]] && { set -a; source .env; set +a; }

echo "  Containers:"
assert_container_running "postgres"
assert_container_running "redis"
assert_container_healthy "postgres"
assert_container_healthy "redis"

echo "  PostgreSQL connectivity:"
skip_if_not_running "postgres" && {
  result=$(docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -c '\l' 2>/dev/null | grep -c "nextcloud\|gitea\|outline" || echo "0")
  [[ "$result" -ge 2 ]] && \
    echo "    ✅ Service databases exist ($result found)" && ((PASS++)) || \
    { echo "    ❌ Service databases missing (found: $result)"; ((FAIL++)); }
}

echo "  Redis connectivity:"
skip_if_not_running "redis" && {
  pong=$(docker exec redis redis-cli -a "${REDIS_PASSWORD:-}" ping 2>/dev/null || echo "FAIL")
  assert_eq "Redis PING" "PONG" "$pong"
}
