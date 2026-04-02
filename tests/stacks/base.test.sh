#!/usr/bin/env bash
# =============================================================================
# Base Stack Integration Tests
# Tests: Traefik, Portainer, Watchtower
# =============================================================================

STACK_NAME="base"

# =============================================================================
# Configuration Tests
# =============================================================================

test_compose_syntax() {
  local msg="Compose file syntax should be valid"
  if docker compose -f "$ROOT_DIR/stacks/base/docker-compose.yml" config --quiet 2>&1; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "Compose config validation failed"
  fi
}

test_no_latest_tags() {
  local msg="No services should use :latest tag"
  local count
  count=$(grep -r 'image:.*:latest' "$ROOT_DIR/stacks/base/" | wc -l | tr -d ' ')
  
  if [ "$count" -eq 0 ]; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "Found $count services using :latest tag"
  fi
}

test_all_services_have_healthcheck() {
  local msg="All services should have healthcheck defined"
  local services
  services=$(docker compose -f "$ROOT_DIR/stacks/base/docker-compose.yml" config --services)
  
  local missing=0
  for service in $services; do
    if ! docker compose -f "$ROOT_DIR/stacks/base/docker-compose.yml" config \
         | jq -e ".services.${service}.healthcheck" > /dev/null 2>&1; then
      missing=$((missing + 1))
    fi
  done
  
  if [ "$missing" -eq 0 ]; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "$missing services missing healthcheck"
  fi
}

# =============================================================================
# Container Health Tests
# =============================================================================

test_traefik_running() {
  assert_container_running "traefik" "Traefik container should be running"
}

test_traefik_healthy() {
  assert_container_healthy "traefik" 60 "Traefik container should be healthy"
}

test_portainer_running() {
  assert_container_running "portainer" "Portainer container should be running"
}

test_portainer_healthy() {
  assert_container_healthy "portainer" 60 "Portainer container should be healthy"
}

test_watchtower_running() {
  assert_container_running "watchtower" "Watchtower container should be running"
}

# =============================================================================
# HTTP Endpoint Tests
# =============================================================================

test_traefik_api() {
  assert_http_200 "http://localhost:8080/api/version" 30 "Traefik API should be accessible"
}

test_traefik_dashboard() {
  assert_http_200 "http://localhost:8080/dashboard/" 30 "Traefik dashboard should be accessible"
}

test_portainer_api() {
  assert_http_200 "http://localhost:9000/api/status" 30 "Portainer API should be accessible"
}

test_portainer_ui() {
  assert_http_200 "http://localhost:9000/" 30 "Portainer UI should be accessible"
}

# =============================================================================
# Network Tests
# =============================================================================

test_proxy_network_exists() {
  local msg="Proxy network should exist"
  if docker network ls --filter "name=proxy" --format "{{.Name}}" | grep -q "^proxy$"; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "Proxy network not found"
  fi
}

test_traefik_in_proxy_network() {
  local msg="Traefik should be in proxy network"
  if container_in_network "traefik" "proxy"; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "Traefik not in proxy network"
  fi
}

test_portainer_in_proxy_network() {
  local msg="Portainer should be in proxy network"
  if container_in_network "portainer" "proxy"; then
    log_test_pass "$msg"
  else
    log_test_fail "$msg" "Portainer not in proxy network"
  fi
}

# =============================================================================
# Run Tests
# =============================================================================

run_all_tests() {
  echo "Running Configuration Tests..."
  test_compose_syntax
  test_no_latest_tags
  test_all_services_have_healthcheck
  
  echo ""
  echo "Running Container Health Tests..."
  test_traefik_running
  test_traefik_healthy
  test_portainer_running
  test_portainer_healthy
  test_watchtower_running
  
  echo ""
  echo "Running HTTP Endpoint Tests..."
  test_traefik_api
  test_traefik_dashboard
  test_portainer_api
  test_portainer_ui
  
  echo ""
  echo "Running Network Tests..."
  test_proxy_network_exists
  test_traefik_in_proxy_network
  test_portainer_in_proxy_network
}

run_all_tests
