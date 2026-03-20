#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage:
#   ./tests/run-tests.sh                  # Run all tests
#   ./tests/run-tests.sh --stack base     # Run single stack tests
#   ./tests/run-tests.sh --stack base,media  # Run multiple stacks
#   ./tests/run-tests.sh --all            # Run all (including e2e)
#   ./tests/run-tests.sh --level 1        # Run only level 1 tests
#   ./tests/run-tests.sh --json           # Output JSON report
#   ./tests/run-tests.sh --ci             # CI mode (no color, JSON output)
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$TESTS_DIR/.."

# Load environment
for envfile in "$BASE_DIR/.env" "$BASE_DIR/config/.env"; do
  [[ -f "$envfile" ]] && set -a && source "$envfile" && set +a
done

# Export counters for assertion library
export TEST_PASSED=0
export TEST_FAILED=0
export TEST_SKIPPED=0
export TEST_RESULTS_FILE="/tmp/homelab-test-results.json"
export TEST_REPORT_JSON="/tmp/homelab-test-report.json"

# Source libraries
source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"
source "$TESTS_DIR/lib/report.sh"

# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------
STACK_FILTER=""
RUN_E2E=false
TEST_LEVEL=99     # Run all levels by default
JSON_OUTPUT=false
CI_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      STACK_FILTER="$2"
      shift 2
      ;;
    --all)
      RUN_E2E=true
      shift
      ;;
    --level)
      TEST_LEVEL="$2"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --ci)
      CI_MODE=true
      JSON_OUTPUT=true
      # Disable colors in CI
      _RED=''; _GREEN=''; _YELLOW=''; _NC=''
      _R_RED=''; _R_GREEN=''; _R_YELLOW=''; _R_BLUE=''; _R_BOLD=''; _R_NC=''
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --stack NAME    Run tests for specific stack(s) (comma-separated)"
      echo "  --all           Run all tests including E2E"
      echo "  --level N       Run tests up to level N (1-4)"
      echo "  --json          Generate JSON report"
      echo "  --ci            CI mode (no color, JSON output)"
      echo "  --help          Show this help"
      echo ""
      echo "Stacks: base, databases, sso, monitoring, media, productivity,"
      echo "        storage, network, ai, home-automation, dashboard, notifications"
      echo ""
      echo "Levels: 1=Container health, 2=HTTP endpoints, 3=Service interconnection, 4=E2E"
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --help)"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
  local missing=()
  command -v docker &>/dev/null || missing+=("docker")
  command -v curl &>/dev/null   || missing+=("curl")
  command -v jq &>/dev/null     || missing+=("jq")
  command -v nc &>/dev/null     || missing+=("nc (netcat)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required tools: ${missing[*]}"
    echo "Install them before running tests."
    exit 1
  fi

  if ! docker info &>/dev/null; then
    echo "ERROR: Docker daemon is not running or not accessible."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Test file runner
# ---------------------------------------------------------------------------
should_run_stack() {
  local stack="$1"
  if [[ -z "$STACK_FILTER" ]]; then
    return 0
  fi
  # Check comma-separated list
  IFS=',' read -ra stacks <<< "$STACK_FILTER"
  for s in "${stacks[@]}"; do
    [[ "$s" == "$stack" ]] && return 0
  done
  return 1
}

run_test_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    source "$file"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  check_dependencies
  init_results

  local start_time
  start_time=$(date +%s)

  echo ""
  echo "HomeLab Stack Integration Tests"
  echo "================================"
  echo "  Time:  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  Filter: ${STACK_FILTER:-all stacks}"
  echo "  Level: ${TEST_LEVEL}"
  echo ""

  # --- Level 1: Configuration integrity (always runs first) ---
  if [[ "$TEST_LEVEL" -ge 1 ]]; then
    log_group "Configuration Integrity (Level 1)"

    # Validate all compose file syntax
    test_compose_syntax() {
      local file
      while IFS= read -r -d '' file; do
        local result
        result=$(docker compose -f "$file" config --quiet 2>&1)
        local rc=$?
        if [[ $rc -eq 0 ]]; then
          _record_result pass "Compose syntax: ${file#$BASE_DIR/}"
        else
          _record_result fail "Compose syntax: ${file#$BASE_DIR/}" "$result"
        fi
      done < <(find "$BASE_DIR/stacks" -name 'docker-compose.yml' -print0 2>/dev/null)
    }
    test_compose_syntax

    # Check no :latest tags in compose files
    test_no_latest_tags() {
      local count
      count=$(grep -r 'image:.*:latest' "$BASE_DIR/stacks/" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l | tr -d ' ')
      assert_eq "$count" "0" "No :latest image tags in compose files"
    }
    test_no_latest_tags

    # Check all services have healthcheck defined in compose
    test_healthchecks_defined() {
      local file
      while IFS= read -r -d '' file; do
        local services
        services=$(docker compose -f "$file" config --services 2>/dev/null)
        for svc in $services; do
          local has_hc
          has_hc=$(docker compose -f "$file" config 2>/dev/null | \
            python3 -c "
import sys, json
try:
    import yaml
    data = yaml.safe_load(sys.stdin)
except:
    sys.exit(0)
svc = '$svc'
if svc in data.get('services', {}):
    if 'healthcheck' in data['services'][svc]:
        print('yes')
    else:
        print('no')
" 2>/dev/null || echo "skip")
          if [[ "$has_hc" == "no" ]]; then
            _record_result fail "Service '$svc' has healthcheck" "in ${file#$BASE_DIR/}"
          elif [[ "$has_hc" == "yes" ]]; then
            _record_result pass "Service '$svc' has healthcheck"
          fi
          # skip = can't parse, don't fail
        done
      done < <(find "$BASE_DIR/stacks" -name 'docker-compose.yml' -print0 2>/dev/null)
    }
    test_healthchecks_defined
  fi

  # --- Stack tests ---
  local stack_tests=(
    "base"
    "databases"
    "sso"
    "monitoring"
    "media"
    "productivity"
    "storage"
    "network"
    "ai"
    "home-automation"
    "dashboard"
    "notifications"
  )

  for stack in "${stack_tests[@]}"; do
    if should_run_stack "$stack"; then
      local test_file="$TESTS_DIR/stacks/${stack}.test.sh"
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file"
      fi
    fi
  done

  # --- E2E tests (Level 4) ---
  if [[ "$RUN_E2E" == true && "$TEST_LEVEL" -ge 4 ]]; then
    log_group "End-to-End Tests (Level 4)"
    for e2e_file in "$TESTS_DIR"/e2e/*.test.sh; do
      [[ -f "$e2e_file" ]] && run_test_file "$e2e_file"
    done
  fi

  # --- Report ---
  local end_time duration
  end_time=$(date +%s)
  duration=$(( end_time - start_time ))

  print_failures
  print_summary "$duration"

  if [[ "$JSON_OUTPUT" == true ]]; then
    generate_json_report "$duration" "${STACK_FILTER:-all}"
  fi

  # Exit code
  [[ "$TEST_FAILED" -eq 0 ]] && exit 0 || exit 1
}

main "$@"
