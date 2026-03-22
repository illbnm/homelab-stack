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

assert_http_ok() {
  local url=$1
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    echo "    ✅ HTTP reachable ($code): $url"
    ((PASS++))
  else
    echo "    ❌ HTTP unreachable ($code): $url"
    ((FAIL++))
  fi
}

assert_port_open() {
  local host=$1 port=$2
  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo "    ✅ port open: $host:$port"
    ((PASS++))
  else
    echo "    ❌ port closed: $host:$port"
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

assert_http_200() {
  local url=$1
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "    ✅ HTTP 200: $url"
    ((PASS++))
  else
    echo "    ❌ HTTP $code: $url"
    ((FAIL++))
  fi
}

assert_http_response() {
  local url=$1
  local expected=$2
  local body
  body=$(curl -sk --max-time 10 "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "$expected"; then
    echo "    ✅ HTTP response contains '$expected': $url"
    ((PASS++))
  else
    echo "    ❌ HTTP response missing '$expected': $url"
    ((FAIL++))
  fi
}

assert_file_exists() {
  local path=$1
  if [[ -f "$path" ]]; then
    echo "    ✅ file exists: $path"
    ((PASS++))
  else
    echo "    ❌ file missing: $path"
    ((FAIL++))
  fi
}

assert_executable() {
  local path=$1
  if [[ -x "$path" ]]; then
    echo "    ✅ executable: $path"
    ((PASS++))
  else
    echo "    ❌ not executable: $path"
    ((FAIL++))
  fi
}

run_test() {
  local fn=$1
  echo "  → $fn"
  "$fn" || true
}

skip_if_not_running() {
  local container=$1
  if ! docker inspect "$container" &>/dev/null; then
    echo "    ⏭ Skipping — $container not running"
    return 1
  fi
  return 0
}
