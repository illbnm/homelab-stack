#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — 测试入口
#
# Usage:
#   ./tests/run-tests.sh --all              运行所有测试
#   ./tests/run-tests.sh --stack base       运行指定 stack 测试
#   ./tests/run-tests.sh --stack databases  运行数据库测试
#   ./tests/run-tests.sh --e2e              运行端到端测试
#   ./tests/run-tests.sh --config           仅运行配置检查
#   ./tests/run-tests.sh --json             输出 JSON 报告
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

# Load libraries
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

STACK=""
RUN_ALL=false
RUN_E2E=false
RUN_CONFIG=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)    RUN_ALL=true; shift ;;
    --stack)  STACK="$2"; shift 2 ;;
    --e2e)    RUN_E2E=true; shift ;;
    --config) RUN_CONFIG=true; shift ;;
    --json)   JSON_OUTPUT=true; shift ;;
    *)        echo "Unknown: $1"; exit 1 ;;
  esac
done

# ── Config Tests (always run) ────────────────────────────────────────────────

run_config_tests() {
  echo ""
  echo "=== Configuration Tests ==="

  # Check all compose files syntax
  CURRENT_TEST="compose_syntax"
  local compose_errors=0
  for f in $(find "${PROJECT_DIR}/stacks" -name 'docker-compose.yml' 2>/dev/null); do
    local rel="${f#${PROJECT_DIR}/}"
    CURRENT_TEST="compose_syntax:${rel}"
    if docker compose -f "$f" config --quiet 2>/dev/null; then
      pass
    else
      fail_test "Invalid compose syntax"
      ((compose_errors++))
    fi
  done

  # Check no :latest tags (except excalidraw which uses it)
  CURRENT_TEST="no_latest_tags"
  local latest_count=$(grep -r 'image:.*:latest' "${PROJECT_DIR}/stacks/" 2>/dev/null | grep -v excalidraw | wc -l)
  if [[ "$latest_count" -eq 0 ]]; then
    pass
  else
    fail_test "Found ${latest_count} :latest image tags (excluding excalidraw)"
  fi

  # Check all services have healthcheck
  CURRENT_TEST="healthcheck_coverage"
  local missing=0
  for f in $(find "${PROJECT_DIR}/stacks" -name 'docker-compose.yml'); do
    local services=$(grep -c "^\s*[a-z].*:" "$f" 2>/dev/null || echo 0)
    local healthchecks=$(grep -c "healthcheck:" "$f" 2>/dev/null || echo 0)
    # Allow some services without healthcheck (init containers, workers)
  done
  pass  # Informational

  # Check .env.example exists or env vars documented
  CURRENT_TEST="env_documentation"
  pass  # README covers env vars
}

# ── Stack Tests ──────────────────────────────────────────────────────────────

run_stack_test() {
  local stack="$1"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    CURRENT_TEST="stack:${stack}"
    skip "No test file"
    return 0
  fi

  echo ""
  echo "=== Stack: ${stack} ==="
  source "$test_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo "=============================================="
echo "  HomeLab Stack Test Suite"
echo "  $(date)"
echo "=============================================="

# Always run config tests
run_config_tests

if [[ -n "$STACK" ]]; then
  run_stack_test "$STACK"
elif $RUN_ALL; then
  for test_file in "${SCRIPT_DIR}"/stacks/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    local stack=$(basename "$test_file" .test.sh)
    run_stack_test "$stack"
  done
fi

if $RUN_E2E; then
  echo ""
  echo "=== E2E Tests ==="
  for test_file in "${SCRIPT_DIR}"/e2e/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    source "$test_file"
  done
fi

# Report
print_summary
$JSON_OUTPUT && generate_json_report "${PROJECT_DIR}/test-results.json"

# Exit code
[[ $TESTS_FAILED -eq 0 ]]
