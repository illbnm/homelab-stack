#!/bin/bash
# databases.test.sh - Database stack tests
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Load environment
if [ -f "${SCRIPT_DIR}/../../.env" ]; then
    export $(grep -E '^[A-Z]' "${SCRIPT_DIR}/../../.env" | xargs 2>/dev/null)
fi

echo "Running Database Stack Tests..."

# PostgreSQL tests
test_start "postgres container is running"
docker ps --format '{{.Names}}' | grep -q "homelab-postgres" && test_pass || test_fail

test_start "postgres container is healthy"
if docker ps --format '{{.Names}}' | grep -q "homelab-postgres"; then
    local health=$(docker inspect --format='{{.State.Health.Status}}' homelab-postgres 2>/dev/null || echo "none")
    [ "$health" = "healthy" ] && test_pass || test_fail "Postgres health: $health"
else
    test_fail "Postgres not found"
fi

test_start "postgres accepts connections"
docker exec homelab-postgres pg_isready -U postgres >/dev/null 2>&1 && test_pass || test_fail

test_start "postgres lists databases"
docker exec homelab-postgres psql -U postgres -l >/dev/null 2>&1 && test_pass || test_fail

# Redis tests
test_start "redis container is running"
docker ps --format '{{.Names}}' | grep -q "homelab-redis" && test_pass || test_fail

test_start "redis accepts commands"
if docker ps --format '{{.Names}}' | grep -q "homelab-redis"; then
    docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" ping >/dev/null 2>&1 && test_pass || test_fail
else
    test_fail "Redis not found"
fi

# MariaDB tests
test_start "mariadb container is running"
docker ps --format '{{.Names}}' | grep -q "homelab-mariadb" && test_pass || test_fail

test_start "mariadb is healthy"
if docker ps --format '{{.Names}}' | grep -q "homelab-mariadb"; then
    local health=$(docker inspect --format='{{.State.Health.Status}}' homelab-mariadb 2>/dev/null || echo "none")
    [ "$health" = "healthy" ] && test_pass || test_fail "MariaDB health: $health"
else
    # MariaDB might not be running, skip
    test_start "mariadb container is running"
    test_fail "MariaDB not found"
fi

# pgAdmin tests
test_start "pgadmin container is running"
docker ps --format '{{.Names}}' | grep -q "homelab-pgadmin" && test_pass || test_fail

test_start "pgadmin web UI accessible"
curl -sf http://localhost:5050 >/dev/null 2>&1 && test_pass || test_fail

# Redis Commander tests
test_start "redis-commander container is running"
docker ps --format '{{.Names}}' | grep -q "homelab-redis-commander" && test_pass || test_fail
