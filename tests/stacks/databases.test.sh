#!/usr/bin/env bash
assert_suite "databases"

test_postgres_running() {
    assert_container_running postgres
}

test_postgres_healthy() {
    assert_container_healthy postgres 60
}

test_redis_running() {
    assert_container_running redis
}

test_redis_healthy() {
    assert_container_healthy redis 60
}

test_mariadb_running() {
    assert_container_running mariadb
}

test_mariadb_healthy() {
    assert_container_healthy mariadb 60
}

test_pgadmin_running() {
    assert_container_running pgadmin
}

test_redis_commander_running() {
    assert_container_running redis-commander
}

test_postgres_running
test_postgres_healthy
test_redis_running
test_redis_healthy
test_mariadb_running
test_mariadb_healthy
test_pgadmin_running
test_redis_commander_running