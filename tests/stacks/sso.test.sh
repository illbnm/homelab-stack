#!/bin/bash
# sso.test.sh - SSO Stack 测试
# 测试 Authentik, PostgreSQL, Redis

set -u

# Authentik 测试
test_authentik_running() {
    assert_container_running "authentik-server"
}

test_authentik_http() {
    assert_http_200 "http://localhost:9000"
}

test_authentik_api() {
    assert_http_response "http://localhost:9000/api/v3/core/users/?page_size=1" "results" "Authentik API v3"
}

# Authentik Worker 测试
test_authentik_worker_running() {
    assert_container_running "authentik-worker"
}

# PostgreSQL for Authentik 测试
test_authentik_postgres_running() {
    assert_container_running "authentik-postgres"
}

# Redis for Authentik 测试
test_authentik_redis_running() {
    assert_container_running "authentik-redis"
}
