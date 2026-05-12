test_postgres_running() { assert_container_running "homelab-postgres"; }
test_postgres_healthy() { assert_container_healthy "homelab-postgres"; }
test_redis_running() { assert_container_running "homelab-redis"; }
test_redis_healthy() { assert_container_healthy "homelab-redis"; }
test_mariadb_running() { assert_container_running "homelab-mariadb"; }
test_mariadb_healthy() { assert_container_healthy "homelab-mariadb"; }
test_pgadmin_running() { assert_container_running "homelab-pgadmin"; }
test_pgadmin_http() { assert_http_200 "http://localhost:8081/login" 10; }
test_redis_commander_running() { assert_container_running "homelab-redis-commander"; }
