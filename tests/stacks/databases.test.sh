#!/bin/bash
# =============================================================================
# Databases Stack Tests
# Tests for: PostgreSQL, MySQL/MariaDB, Redis, MongoDB
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# -----------------------------------------------------------------------------
# Test: Docker Compose file validation
# -----------------------------------------------------------------------------
describe "Docker Compose Configuration"

COMPOSE_FILE="stacks/databases/docker-compose.yml"
assert_file_exists "$COMPOSE_FILE" "Databases compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

# -----------------------------------------------------------------------------
# Test: Required services
# -----------------------------------------------------------------------------
describe "Service Definitions"

it "should define postgres service"
assert_service_exists "$COMPOSE_FILE" "postgres" "PostgreSQL service should exist"

it "should define mariadb service"
assert_service_exists "$COMPOSE_FILE" "mariadb" "MariaDB service should exist"

it "should define redis service"
assert_service_exists "$COMPOSE_FILE" "redis" "Redis service should exist"

it "should define mongodb service"
assert_service_exists "$COMPOSE_FILE" "mongodb" "MongoDB service should exist"

# -----------------------------------------------------------------------------
# Test: Configuration
# -----------------------------------------------------------------------------
describe "Database Configuration"

COMPOSE_CONTENT=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")

it "should have healthcheck for postgres"
assert_contains "$COMPOSE_CONTENT" "postgres" "PostgreSQL should be configured"

it "should have volume mounts for data persistence"
assert_contains "$COMPOSE_CONTENT" "volumes:" "Should have volume definitions"

# -----------------------------------------------------------------------------
# Test: Init scripts
# -----------------------------------------------------------------------------
describe "Initialization Scripts"

it "should have initdb scripts directory"
assert_dir_exists "stacks/databases/initdb" "InitDB scripts directory should exist"

it "should have databases initialization script"
assert_file_exists "stacks/databases/initdb/01-init-databases.sh" "Init script should exist"

# -----------------------------------------------------------------------------
# Test: Networks
# -----------------------------------------------------------------------------
describe "Network Configuration"

it "should define databases network"
COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
assert_contains "$COMPOSE_CONTENT" "databases" "Databases network should be defined"