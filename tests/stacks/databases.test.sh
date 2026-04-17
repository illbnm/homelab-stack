#!/usr/bin/env bash
# tests/stacks/databases.test.sh

describe "Databases Stack (PostgreSQL + MySQL + Redis)"

it "PostgreSQL container is running"
if container_exists "homelab-postgres"; then
    assert_container_running "homelab-postgres"
    it "PostgreSQL accepts connections"
    assert_exit_code 0 "docker exec homelab-postgres pg_isready -U postgres"
    it "PostgreSQL is not crash-looping"
    assert_container_restarted "homelab-postgres" 3
else
    skip "PostgreSQL not found"
fi

it "MySQL container is running"
if container_exists "homelab-mysql"; then
    assert_container_running "homelab-mysql"
    it "MySQL is not crash-looping"
    assert_container_restarted "homelab-mysql" 3
else
    skip "MySQL not found"
fi

it "Redis container is running"
if container_exists "homelab-redis"; then
    assert_container_running "homelab-redis"
    it "Redis accepts connections"
    assert_exit_code 0 "docker exec homelab-redis redis-cli ping"
    it "Redis is not crash-looping"
    assert_container_restarted "homelab-redis" 3
else
    skip "Redis not found"
fi
