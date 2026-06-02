#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
#
# Usage:
#   ./tests/run-tests.sh                  # Run all tests
#   ./tests/run-tests.sh --stack base     # Test only base stack
#   ./tests/run-tests.sh --stack network  # Test only network stack
#   ./tests/run-tests.sh --stack sso      # Test only SSO stack
#   ./tests/run-tests.sh --json           # Output JSON only (no colors)
#   ./tests/run-tests.sh --compose-check  # Validate all compose file syntax
#   ./tests/run-tests.sh --no-latest      # Check for :latest image tags
#   ./tests/run-tests.sh --help           # Show this help
#
# ARM64 compatible — all tests work on ARM64 and x86_64.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
STACKS_DIR="$BASE_DIR/stacks"

export SCRIPT_DIR BASE_DIR STACKS_DIR
export RESULT_DIR="$SCRIPT_DIR/results"

source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

RUN_STACK=""
COMPOSE_CHECK=false
NO_LATEST_CHECK=false
JSON_ONLY=false
START_TIME=0

usage() {
  echo ""
  echo -e "${BOLD}HomeLab Stack — Integration Test Runner${NC}"
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --stack <name>     Test only a specific stack"
  echo "  --all              Run tests for all stacks (default)"
  echo "  --compose-check    Validate all compose file syntax"
  echo "  --no-latest        Check for :latest image tags in all compose files"
  echo "  --json             Output JSON report only (no colored terminal)"
  echo "  --help             Show this help message"
  echo ""
  echo "Available stacks:"
  for d in "$STACKS_DIR"/*/; do
    local name
    name=$(basename "$d")
    if [[ -f "$SCRIPT_DIR/stacks/${name}.test.sh" ]]; then
      echo "  - $name"
    fi
  done
  echo ""
  echo "Examples:"
  echo "  $0 --stack base      # Test base stack only"
  echo "  $0 --compose-check   # Validate all compose files"
  echo "  $0 --json            # JSON output"
  echo ""
  echo "Platform: ARM64 + x86_64 compatible"
  exit 1
}

run_test_with_timing() {
  local stack="$1" test_fn="$2" label="$3"
  local start result duration
  start=$(date +%s%N 2>/dev/null || echo 0)

  if "$test_fn" 2>/dev/null; then
    result="PASS"
  else
    result="FAIL"
  fi

  local end
  end=$(date +%s%N 2>/dev/null || echo 0)
  duration=$(echo "scale=1; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "0.0")

  if [[ "$JSON_ONLY" != "true" ]]; then
    report_test "$stack" "$label" "$result" "$duration"
  fi
}

run_stack_tests() {
  local stack="$1"
  local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    if [[ "$JSON_ONLY" != "true" ]]; then
      echo -e "  ${YELLOW}No test file for stack: $stack${NC}"
    fi
    return 0
  fi

  if [[ "$JSON_ONLY" != "true" ]]; then
    print_stack_header "$stack"
  fi

  source "$test_file"
}

do_compose_check() {
  if [[ "$JSON_ONLY" != "true" ]]; then
    echo ""
    echo -e "${BOLD}${BLUE}═══ Compose Config Validation ═══${NC}"
  fi

  local passed=0 failed=0
  for f in $(find "$STACKS_DIR" -name 'docker-compose.yml' -o -name 'docker-compose.local.yml' | sort); do
    local stack_name
    stack_name=$(echo "$f" | sed 's|.*/stacks/||;s|/.*||')
    if compose_config_validate "$f"; then
      if [[ "$JSON_ONLY" != "true" ]]; then
        report_test "config" "$stack_name compose valid" "PASS" "0.0"
      fi
      passed=$((passed + 1))
    else
      if [[ "$JSON_ONLY" != "true" ]]; then
        report_test "config" "$stack_name compose valid" "FAIL" "0.0"
      fi
      failed=$((failed + 1))
    fi
  done
}

do_no_latest_check() {
  if [[ "$JSON_ONLY" != "true" ]]; then
    echo ""
    echo -e "${BOLD}${BLUE}═══ Image Tag Validation (:latest check) ═══${NC}"
  fi

  local count
  count=$(grep -r 'image:.*:latest' "$STACKS_DIR" 2>/dev/null | wc -l || echo 0)
  if [[ "$count" -eq 0 ]]; then
    if [[ "$JSON_ONLY" != "true" ]]; then
      report_test "images" "No :latest tags found" "PASS" "0.0"
    fi
  else
    if [[ "$JSON_ONLY" != "true" ]]; then
      report_test "images" "$count :latest tags found" "FAIL" "0.0"
      echo ""
      grep -rn 'image:.*:latest' "$STACKS_DIR" 2>/dev/null || true
    fi
  fi
}

# ------- Main --------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)    RUN_STACK="$2"; shift 2 ;;
    --all)      RUN_STACK=""; shift ;;
    --compose-check) COMPOSE_CHECK=true; shift ;;
    --no-latest)     NO_LATEST_CHECK=true; shift ;;
    --json)     JSON_ONLY=true; shift ;;
    --help|-h)  usage ;;
    *)          echo "Unknown option: $1"; usage ;;
  esac
done

report_init

if [[ "$JSON_ONLY" != "true" ]]; then
  print_header
fi

if [[ "$COMPOSE_CHECK" == true ]]; then
  do_compose_check
fi

if [[ "$NO_LATEST_CHECK" == true ]]; then
  do_no_latest_check
fi

if [[ -n "$RUN_STACK" ]]; then
  run_stack_tests "$RUN_STACK"
else
  declare -a STACK_ORDER=(base databases sso monitoring network storage productivity media ai notifications home-automation dashboard)
  for stack in "${STACK_ORDER[@]}"; do
    if [[ -f "$SCRIPT_DIR/stacks/${stack}.test.sh" ]]; then
      run_stack_tests "$stack"
    fi
  done
fi

write_json_report

if [[ "$JSON_ONLY" != "true" ]]; then
  print_summary
fi

if [[ $GLOBAL_FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
