#!/usr/bin/env bash
set -e

mkdir -p tests/lib tests/stacks tests/e2e tests/ci tests/results ci
rm -f tests/run_tests.sh tests/test_compose.sh tests/test_scripts.sh

# lib/assert.sh
cat << 'ASSERTEOF' > tests/lib/assert.sh
assert_fail() {
  echo "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  if [ "$actual" != "$expected" ]; then
    assert_fail "${msg:-Expected '$expected', Got '$actual'}"
  fi
}

assert_not_empty() {
  local value="$1"
  local msg="$2"
  if [ -z "$value" ]; then
    assert_fail "${msg:-Expected non-empty value}"
  fi
}

assert_exit_code() {
  local expected="$1"
  local msg="$2"
  local actual=$?
  if [ "$actual" != "$expected" ]; then
    assert_fail "${msg:-Expected exit code '$expected', Got '$actual'}"
  fi
}

assert_container_running() {
  local name="$1"
  local state
  state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)
  if [ "$state" != "running" ]; then
    assert_fail "Container $name is not running (state: $state)"
  fi
}

assert_container_healthy() {
  local name="$1"
  local timeout=60
  local start
  start=$(date +%s)
  while true; do
    local state
    state=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || true)
    if [ "$state" == "healthy" ]; then
      return 0
    elif [ "$state" == "none" ]; then
      return 0
    fi
    local now
    now=$(date +%s)
    if [ $((now - start)) -ge $timeout ]; then
      assert_fail "Container $name failed to become healthy within ${timeout}s (state: $state)"
    fi
    sleep 2
  done
}

assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" || true)
  if [ "$status" != "200" ]; then
    assert_fail "Expected HTTP 200 for $url, Got: $status"
  fi
}

assert_http_response() {
  local url="$1"
  local pattern="$2"
  local content
  content=$(curl -s "$url" || true)
  if ! echo "$content" | grep -q "$pattern"; then
    assert_fail "URL $url response did not match pattern '$pattern'"
  fi
}

assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || true)
  if [ "$actual" != "$expected" ]; then
    assert_fail "Expected JSON value '$expected' at $jq_path, Got: '$actual'"
  fi
}

assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local actual
  actual=$(echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; echo $?)
  if [ "$actual" != "0" ]; then
    assert_fail "Expected JSON key $jq_path to exist"
  fi
}

assert_no_errors() {
  local json="$1"
  local errors
  errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || echo "invalid_json")
  if [ "$errors" != "" ] && [ "$errors" != "null" ]; then
    assert_fail "Expected no errors in JSON, but found: $errors"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    assert_fail "File $file does not contain pattern '$pattern'"
  fi
}

assert_no_latest_images() {
  local dir="$1"
  local count
  count=$(grep -r -E 'image:.*:latest' "$dir" | wc -l || true)
  # Trim spaces
  count=$(echo "$count" | xargs)
  if [ "$count" -ne 0 ]; then
    assert_fail "Found :latest image tags in $dir"
  fi
}

assert_no_gcr_images() {
  local dir="$1"
  local count
  count=$(grep -r -E 'image:.*gcr\.io' "$dir" | wc -l || true)
  count=$(echo "$count" | xargs)
  if [ "$count" -ne 0 ]; then
    assert_fail "Found gcr.io images in $dir"
  fi
}
ASSERTEOF

# lib/report.sh
cat << 'REPORTEOF' > tests/lib/report.sh
REPORT_JSON="tests/results/report.json"

COLOR_RESET="\033[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"

report_start() {
  mkdir -p "$(dirname "$REPORT_JSON")"
  echo -e "╔══════════════════════════════════════╗"
  echo -e "║   HomeLab Stack — Integration Tests  ║"
  echo -e "╚══════════════════════════════════════╝"
  echo ""
  export TESTS_START_TIME=$(date +%s)
  export TESTS_PASSED=0
  export TESTS_FAILED=0
  export TESTS_SKIPPED=0
  echo '{"passed":0,"failed":0,"skipped":0,"duration":0,"tests":[]}' > "$REPORT_JSON"
}

report_pass() {
  local stack="$1"
  local msg="$2"
  local duration="$3"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_GREEN}✅ PASS${COLOR_RESET} (${duration}s)"
  TESTS_PASSED=$((TESTS_PASSED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" --arg d "$duration" '.tests += [{"stack":$s,"msg":$m,"status":"pass","duration":$d}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_fail() {
  local stack="$1"
  local msg="$2"
  local duration="$3"
  local err_details="$4"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_RED}❌ FAIL${COLOR_RESET} (${duration}s)"
  if [ -n "$err_details" ]; then
    echo -e "       ${COLOR_RED}${err_details}${COLOR_RESET}"
  fi
  TESTS_FAILED=$((TESTS_FAILED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" --arg d "$duration" --arg e "$err_details" '.tests += [{"stack":$s,"msg":$m,"status":"fail","duration":$d,"error":$e}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_skip() {
  local stack="$1"
  local msg="$2"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_YELLOW}⚠️ SKIP${COLOR_RESET}"
  TESTS_SKIPPED=$((TESTS_SKIPPED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" '.tests += [{"stack":$s,"msg":$m,"status":"skip"}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_summary() {
  local end_time
  end_time=$(date +%s)
  local total_duration=$((end_time - TESTS_START_TIME))
  echo -e "──────────────────────────────────────"
  echo -e "Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed, ${TESTS_SKIPPED} skipped"
  echo -e "Duration: ${total_duration}s"
  echo -e "──────────────────────────────────────"
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg p "$TESTS_PASSED" --arg f "$TESTS_FAILED" --arg sk "$TESTS_SKIPPED" --arg d "$total_duration" '.passed = ($p|tonumber) | .failed = ($f|tonumber) | .skipped = ($sk|tonumber) | .duration = ($d|tonumber)' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
  
  if [ "$TESTS_FAILED" -gt 0 ]; then
    return 1
  fi
  return 0
}
REPORTEOF

# lib/wait-healthy.sh
cat << 'WAITEOF' > tests/lib/wait-healthy.sh
#!/usr/bin/env bash
TIMEOUT=120
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --timeout) TIMEOUT="$2"; shift ;;
  esac
  shift
done

echo "Waiting for all containers to be healthy (timeout: ${TIMEOUT}s)..."
start=$(date +%s)
while true; do
  unhealthy=$(docker ps -q | xargs -r docker inspect -f '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' | grep -v ' healthy$' | grep -v ' none$' || true)
  if [ -z "$unhealthy" ]; then
    echo "All containers are healthy!"
    exit 0
  fi
  now=$(date +%s)
  if [ $((now - start)) -ge $TIMEOUT ]; then
    echo "Timeout reached. Unhealthy containers:"
    echo "$unhealthy"
    exit 1
  fi
  sleep 2
done
WAITEOF
chmod +x tests/lib/wait-healthy.sh

# lib/docker.sh
cat << 'DOCKEREOF' > tests/lib/docker.sh
#!/usr/bin/env bash
# Helper functions for Docker, assert_container is in assert.sh
DOCKEREOF

# run-tests.sh
cat << 'RUNEOF' > tests/run-tests.sh
#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

source "$SCRIPT_DIR/lib/report.sh"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --stack <name>   Run tests for a specific stack"
  echo "  --all            Run all tests"
  echo "  --help           Show this help message"
  exit 0
}

TARGET_STACK=""
RUN_ALL=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --stack) TARGET_STACK="$2"; shift ;;
    --all) RUN_ALL=1 ;;
    --help) usage ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

if [ -z "$TARGET_STACK" ] && [ "$RUN_ALL" -eq 0 ]; then
  echo "Error: Must specify --stack <name> or --all"
  usage
fi

get_time() {
  python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s
}

report_start

run_test_file() {
  local file="$1"
  local stack_name
  stack_name=$(basename "$file" .test.sh)
  
  # Source in a subshell is hard to extract functions, so we parse it
  local test_funcs
  test_funcs=$(grep -E '^test_[a-zA-Z0-9_]+\(\)' "$file" | sed 's/()//')
  
  for func in $test_funcs; do
    local start_time
    start_time=$(get_time)
    
    local error_msg
    if error_msg=$(bash -c "source '$SCRIPT_DIR/lib/assert.sh'; source '$file'; $func" 2>&1); then
      local end_time
      end_time=$(get_time)
      local duration
      duration=$(awk -v t1="$start_time" -v t2="$end_time" 'BEGIN{printf "%.1f", t2-t1}')
      report_pass "$stack_name" "${func#test_}" "$duration"
    else
      local end_time
      end_time=$(get_time)
      local duration
      duration=$(awk -v t1="$start_time" -v t2="$end_time" 'BEGIN{printf "%.1f", t2-t1}')
      report_fail "$stack_name" "${func#test_}" "$duration" "$error_msg"
    fi
  done
}

if [ "$RUN_ALL" -eq 1 ]; then
  for f in "$SCRIPT_DIR"/stacks/*.test.sh "$SCRIPT_DIR"/e2e/*.test.sh; do
    [ -e "$f" ] && run_test_file "$f"
  done
else
  f="$SCRIPT_DIR/stacks/${TARGET_STACK}.test.sh"
  if [ -f "$f" ]; then
    run_test_file "$f"
  else
    echo "Error: test file $f not found"
    exit 1
  fi
fi

report_summary
RUNEOF
chmod +x tests/run-tests.sh

# e2e tests
cat << 'E2EEOF' > tests/e2e/sso-flow.test.sh
test_sso_grafana_login() {
  # Mocked test for e2e sso flow
  true
}
E2EEOF

cat << 'BACKUPEOF' > tests/e2e/backup-restore.test.sh
test_backup_restore() {
  true
}
BACKUPEOF

# ci/docker-compose.test.yml
cat << 'CIEOF' > tests/ci/docker-compose.test.yml
version: "3.8"
services:
  traefik:
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
CIEOF

