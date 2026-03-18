#!/usr/bin/env bash
# =============================================================================
# Docker Helper Functions
# Provides utility functions for Docker operations
# =============================================================================

# Check if container is running
container_check() {
  local name="$1"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'no-healthcheck')
    if [[ "$health" == 'healthy' ]] || [[ "$health" == 'no-healthcheck' ]]; then
      log_pass "Container $name is running ($health)"
      return 0
    else
      log_fail "Container $name unhealthy: $health"
      return 1
    fi
  else
    log_skip "Container $name not running"
    return 2
  fi
}

# Check if port is open
port_check() {
  local name="$1"
  local host="${2:-localhost}"
  local port="$3"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    log_pass "$name port $port is open"
    return 0
  else
    log_skip "$name port $port not reachable"
    return 2
  fi
}

# Check HTTP endpoint
http_check() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]] || [[ "$code" =~ ^[23] ]]; then
    log_pass "$name ($url) → HTTP $code"
    return 0
  else
    log_fail "$name ($url) → HTTP $code (expected ~2xx/3xx)"
    return 1
  fi
}

# Get container status
get_container_status() {
  local name="$1"
  docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "not-found"
}

# Check if volume exists
volume_exists() {
  local name="$1"
  if docker volume ls -q | grep -q "^${name}$"; then
    return 0
  else
    return 1
  fi
}

# Check if network exists
network_exists() {
  local name="$1"
  if docker network ls -q | xargs docker network inspect --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
    return 0
  else
    return 1
  fi
}