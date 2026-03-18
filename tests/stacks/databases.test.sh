# Database stack tests

CURRENT_TEST="postgres_running"
assert_container_running "postgres"

CURRENT_TEST="postgres_healthy"
assert_container_healthy "postgres"

CURRENT_TEST="postgres_databases"
local dbs=$(docker exec postgres psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1');" 2>/dev/null | tr -d ' ')
assert_contains "$dbs" "nextcloud" "nextcloud database exists"

CURRENT_TEST="postgres_gitea_db"
assert_contains "$dbs" "gitea" "gitea database exists"

CURRENT_TEST="postgres_outline_db"
assert_contains "$dbs" "outline" "outline database exists"

CURRENT_TEST="postgres_authentik_db"
assert_contains "$dbs" "authentik" "authentik database exists"

CURRENT_TEST="postgres_grafana_db"
assert_contains "$dbs" "grafana" "grafana database exists"

CURRENT_TEST="redis_running"
assert_container_running "redis"

CURRENT_TEST="redis_healthy"
assert_container_healthy "redis"

CURRENT_TEST="redis_ping"
local redis_pong=$(docker exec redis redis-cli -a "${REDIS_PASSWORD:-changeme}" ping 2>/dev/null)
assert_eq "$redis_pong" "PONG" "Redis responds to PING"

CURRENT_TEST="mariadb_running"
assert_container_running "mariadb"

CURRENT_TEST="mariadb_healthy"
assert_container_healthy "mariadb"

CURRENT_TEST="pgadmin_running"
assert_container_running "pgadmin"

CURRENT_TEST="pgadmin_http"
assert_http_200 "http://localhost:80"
