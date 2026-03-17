#!/usr/bin/env bash
# =============================================================================
# assert.sh — Test assertion library
# =============================================================================

PASS=0
FAIL=0
SKIP=0

assert_eq() {
  local desc=$1 expected=$2 actual=$3
  if [[ "$expected" == "$actual" ]]; then
    echo "    ✅ $desc"
    ((PASS++))
  else
    echo "    ❌ $desc"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    ((FAIL++))
  fi
}

assert_container_running() {
  local name=$1
  if docker inspect "$name" &>/dev/null && \
     [[ "$(docker inspect --format='{{.State.Status}}' "$name")" == "running" ]]; then
    echo "    ✅ container running: $name"
    ((PASS++))
  else
    echo "    ❌ container not running: $name"
    ((FAIL++))
  fi
}

assert_container_healthy() {
  local name=$1
  local health
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "missing")
  if [[ "$health" == "healthy" || "$health" == "none" ]]; then
    echo "    ✅ container healthy: $name ($health)"
    ((PASS++))
  else
    echo "    ❌ container unhealthy: $name ($health)"
    ((FAIL++))
  fi
}

assert_http_200() {
  local desc=$1 url=$2
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "    ✅ HTTP 200: $desc ($url)"
    ((PASS++))
  else
    echo "    ❌ HTTP $code: $desc ($url)"
    ((FAIL++))
  fi
}

assert_http_ok() {
  local desc=$1 url=$2
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    echo "    ✅ HTTP reachable ($code): $desc"
    ((PASS++))
  else
    echo "    ❌ HTTP unreachable ($code): $desc ($url)"
    ((FAIL++))
  fi
}

assert_port_open() {
  local desc=$1 host=$2 port=$3
  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo "    ✅ port open: $desc ($host:$port)"
    ((PASS++))
  else
    echo "    ❌ port closed: $desc ($host:$port)"
    ((FAIL++))
  fi
}

assert_env_set() {
  local var=$1
  if [[ -n "${!var:-}" ]]; then
    echo "    ✅ env set: $var"
    ((PASS++))
  else
    echo "    ⏭ env not set: $var (skip)"
    ((SKIP++))
  fi
}

skip_if_not_running() {
  local container=$1
  if ! docker inspect "$container" &>/dev/null; then
    echo "    ⏭ Skipping — $container not running"
    return 1
  fi
  return 0
}
