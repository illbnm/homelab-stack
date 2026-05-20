#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PROJECT_ROOT

# shellcheck source=tests/lib/report.sh
source "$PROJECT_ROOT/tests/lib/report.sh"
# shellcheck source=tests/lib/assert.sh
source "$PROJECT_ROOT/tests/lib/assert.sh"
# shellcheck source=tests/lib/docker.sh
source "$PROJECT_ROOT/tests/lib/docker.sh"

STACKS=(base databases sso monitoring network storage productivity media ai home-automation notifications dashboard)
E2E_TESTS=(sso-flow backup-restore)

usage() {
  cat <<'USAGE'
Usage: tests/run-tests.sh [--stack NAME | --all | --e2e NAME | --list]

Options:
  --stack NAME   Run one stack test suite. Known stacks: base, databases, sso,
                 monitoring, network, storage, productivity, media, ai,
                 home-automation, notifications, dashboard.
  --all          Run every stack suite and every E2E suite.
  --e2e NAME     Run one E2E suite. Known E2E suites: sso-flow, backup-restore.
  --list         Print available stack and E2E suites.
  --help         Show this help.

Reports are written to tests/results/report.json unless REPORT_FILE is set.
USAGE
}

list_suites() {
  printf 'Stacks:\n'
  printf '  %s\n' "${STACKS[@]}"
  printf 'E2E:\n'
  printf '  %s\n' "${E2E_TESTS[@]}"
}

contains() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

function_name_for_suite() {
  local suite=$1
  suite=${suite//-/_}
  printf 'run_%s_tests' "$suite"
}

load_env() {
  local env_file="$PROJECT_ROOT/.env"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
  fi
}

run_stack_suite() {
  local stack=$1
  local file="$PROJECT_ROOT/tests/stacks/$stack.test.sh"
  local function_name
  if ! contains "$stack" "${STACKS[@]}"; then
    printf 'Unknown stack: %s\n' "$stack" >&2
    return 2
  fi
  if [[ ! -f "$file" ]]; then
    printf 'Missing stack test file: %s\n' "$file" >&2
    return 2
  fi
  # shellcheck source=/dev/null
  source "$file"
  function_name=$(function_name_for_suite "$stack")
  "$function_name"
}

run_e2e_suite() {
  local suite=$1
  local file="$PROJECT_ROOT/tests/e2e/$suite.test.sh"
  local function_name
  if ! contains "$suite" "${E2E_TESTS[@]}"; then
    printf 'Unknown E2E suite: %s\n' "$suite" >&2
    return 2
  fi
  if [[ ! -f "$file" ]]; then
    printf 'Missing E2E test file: %s\n' "$file" >&2
    return 2
  fi
  # shellcheck source=/dev/null
  source "$file"
  function_name=$(function_name_for_suite "$suite")
  "$function_name"
}

main() {
  local mode=${1:---help}
  local target=${2:-}
  local suite

  case "$mode" in
    --help|-h)
      usage
      return 0
      ;;
    --list)
      list_suites
      return 0
      ;;
    --stack)
      [[ -n "$target" ]] || { usage >&2; return 2; }
      report_init
      load_env
      run_stack_suite "$target"
      ;;
    --e2e)
      [[ -n "$target" ]] || { usage >&2; return 2; }
      report_init
      load_env
      run_e2e_suite "$target"
      ;;
    --all)
      report_init
      load_env
      for suite in "${STACKS[@]}"; do
        run_stack_suite "$suite"
      done
      for suite in "${E2E_TESTS[@]}"; do
        run_e2e_suite "$suite"
      done
      ;;
    *)
      usage >&2
      return 2
      ;;
  esac

  report_write
  printf '\nSummary: %s passed, %s failed, %s skipped, %s total\n' \
    "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED" "$TESTS_TOTAL"
  printf 'Report: %s\n' "$REPORT_FILE"
  [[ "$TESTS_FAILED" -eq 0 ]]
}

main "$@"
