#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Stack Test Script
# =============================================================================
# Validates that all database services are running correctly.
#
# Usage:
#   ./stacks/databases/scripts/test-databases.sh
#
# Exit codes:
#   0 — All tests passed
#   1 — One or more tests failed
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source .env
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
fi

# ---------------------------------------------------------------------------
# Colors & logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0
FAIL=0

test_pass() { echo -e "  ${GREEN}✓ PASS${NC}: $*"; PASS=$((PASS + 1)); }
test_fail() { echo -e "  ${RED}✗ FAIL${NC}: $*"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Test helper — check container health
# ---------------------------------------------------------------------------
test_container_health() {
  local name="$1"
  local status
  status=$(docker inspect --format='{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "not found")
  if [ "${status}" = "healthy" ]; then
    test_pass "Container '${name}' is healthy"
  else
    test_fail "Container '${name}' status: ${status}"
  fi
}

# ---------------------------------------------------------------------------
# Test helper — check container is NOT exposing ports to host
# ---------------------------------------------------------------------------
test_no_host_ports() {
  local name="$1"
  local ports
  ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}} {{end}}{{end}}' "${name}" 2>/dev/null || echo "")
  if [ -z "${ports}" ]; then
    test_pass "Container '${name}' has no host-exposed ports"
  else
    test_fail "Container '${name}' exposes host ports: ${ports}"
  fi
}

# ---------------------------------------------------------------------------
# Test helper — check container network membership
# ---------------------------------------------------------------------------
test_network_membership() {
  local name="$1"
  local network="$2"
  local should_be_on="$3"  # "yes" or "no"

  local networks
  networks=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "${name}" 2>/dev/null || echo "")

  if echo "${networks}" | grep -q "${network}"; then
    if [ "${should_be_on}" = "yes" ]; then
      test_pass "Container '${name}' is on '${network}' network"
    else
      test_fail "Container '${name}' should NOT be on '${network}' network"
    fi
  else
    if [ "${should_be_on}" = "no" ]; then
      test_pass "Container '${name}' is correctly NOT on '${network}' network"
    else
      test_fail "Container '${name}' should be on '${network}' network"
    fi
  fi
}

# =============================================================================
echo ""
echo "=========================================="
echo "  HomeLab Database Stack — Test Suite"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
echo "--- Container Health Checks ---"
# ---------------------------------------------------------------------------
test_container_health "homelab-postgres"
test_container_health "homelab-redis"
test_container_health "homelab-mariadb"
test_container_health "homelab-pgadmin"
test_container_health "homelab-redis-commander"

# ---------------------------------------------------------------------------
echo ""
echo "--- Network Isolation ---"
# ---------------------------------------------------------------------------
# Database services should be on internal only (not proxy)
test_network_membership "homelab-postgres" "proxy" "no"
test_network_membership "homelab-postgres" "internal" "yes"
test_network_membership "homelab-redis" "proxy" "no"
test_network_membership "homelab-redis" "internal" "yes"
test_network_membership "homelab-mariadb" "proxy" "no"
test_network_membership "homelab-mariadb" "internal" "yes"

# Management UIs should be on BOTH internal and proxy
test_network_membership "homelab-pgadmin" "internal" "yes"
test_network_membership "homelab-pgadmin" "proxy" "yes"
test_network_membership "homelab-redis-commander" "internal" "yes"
test_network_membership "homelab-redis-commander" "proxy" "yes"

# ---------------------------------------------------------------------------
echo ""
echo "--- No Host Port Exposure (Database Services) ---"
# ---------------------------------------------------------------------------
test_no_host_ports "homelab-postgres"
test_no_host_ports "homelab-redis"
test_no_host_ports "homelab-mariadb"

# ---------------------------------------------------------------------------
echo ""
echo "--- PostgreSQL Multi-Tenant Databases ---"
# ---------------------------------------------------------------------------
for db_name in nextcloud gitea outline authentik grafana; do
  if docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" 2>/dev/null | grep -q 1; then
    test_pass "PostgreSQL database '${db_name}' exists"
  else
    test_fail "PostgreSQL database '${db_name}' not found"
  fi
done

# Check users
for db_user in nextcloud gitea outline authentik grafana; do
  if docker exec homelab-postgres psql -U postgres -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname = '${db_user}'" 2>/dev/null | grep -q 1; then
    test_pass "PostgreSQL user '${db_user}' exists"
  else
    test_fail "PostgreSQL user '${db_user}' not found"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "--- PostgreSQL Connectivity ---"
# ---------------------------------------------------------------------------
for db_name in nextcloud gitea outline authentik grafana; do
  pw_var="${db_name^^}_DB_PASSWORD"
  pw="${!pw_var:-}"
  if [ -n "${pw}" ]; then
    if docker exec -e PGPASSWORD="${pw}" homelab-postgres \
      psql -U "${db_name}" -d "${db_name}" -c "SELECT 1;" &>/dev/null; then
      test_pass "User '${db_name}' can connect to database '${db_name}'"
    else
      test_fail "User '${db_name}' cannot connect to database '${db_name}'"
    fi
  else
    test_fail "Password variable ${pw_var} not set — skipping connectivity test"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "--- Redis Connectivity ---"
# ---------------------------------------------------------------------------
if docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" ping 2>/dev/null | grep -q PONG; then
  test_pass "Redis responds to PING"
else
  test_fail "Redis does not respond to PING"
fi

# Test multiple DB selections
for db_num in 0 1 2 3 4; do
  if docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" -n "${db_num}" \
    SET "homelab_test_${db_num}" "ok" EX 5 &>/dev/null; then
    test_pass "Redis DB ${db_num} is accessible"
    docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" -n "${db_num}" \
      DEL "homelab_test_${db_num}" &>/dev/null || true
  else
    test_fail "Redis DB ${db_num} is not accessible"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "--- MariaDB Connectivity ---"
# ---------------------------------------------------------------------------
if docker exec homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD:-}" \
  -e "SELECT 1;" &>/dev/null; then
  test_pass "MariaDB root login works"
else
  test_fail "MariaDB root login failed"
fi

# Check Nextcloud database
if docker exec homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD:-}" \
  -e "SHOW DATABASES;" 2>/dev/null | grep -q nextcloud; then
  test_pass "MariaDB database 'nextcloud' exists"
else
  test_fail "MariaDB database 'nextcloud' not found"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- pgAdmin Accessibility ---"
# ---------------------------------------------------------------------------
if docker exec homelab-pgadmin wget -q --spider http://localhost:80/misc/ping 2>/dev/null; then
  test_pass "pgAdmin web UI is accessible"
else
  test_fail "pgAdmin web UI is not accessible"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- Redis Commander Accessibility ---"
# ---------------------------------------------------------------------------
if docker exec homelab-redis-commander wget -q --spider http://localhost:8081/ 2>/dev/null; then
  test_pass "Redis Commander web UI is accessible"
else
  test_fail "Redis Commander web UI is not accessible"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- docker compose ps ---"
# ---------------------------------------------------------------------------
docker compose -f "${PROJECT_ROOT}/stacks/databases/docker-compose.yml" ps 2>/dev/null || true

# =============================================================================
echo ""
echo "=========================================="
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "=========================================="

if [ "${FAIL}" -gt 0 ]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
