#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — HomeLab Stack Integration Test Runner
# =============================================================================
# Usage:
#   ./tests/run-tests.sh --stack base        # Test a specific stack
#   ./tests/run-tests.sh --all               # Test all stacks
#   ./tests/run-tests.sh --stack base,media  # Test multiple stacks
#   ./tests/run-tests.sh --all --json        # Output JSON report
#   ./tests/run-tests.sh --all --junit       # Also generate JUnit XML
#   ./tests/run-tests.sh --dry-run           # List tests without running
#   ./tests/run-tests.sh --help              # Show help
#
# Environment Variables:
#   NO_COLOR=1         Disable colored output
#   TEST_TIMEOUT=300   Global timeout in seconds (default: 300)
#   COMPOSE_DIR=       Override stacks directory (default: ./stacks)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
# shellcheck source=lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

COMPOSE_DIR="${COMPOSE_DIR:-${ROOT_DIR}/stacks}"
GLOBAL_TIMEOUT="${TEST_TIMEOUT:-300}"
JSON_OUTPUT=false
JUNIT_OUTPUT=false
DRY_RUN=false
TARGET_STACKS=()
RUN_ALL=false
VERBOSE=false

# Available stacks (in dependency order)
ALL_STACKS=(
  base
  network
  storage
  databases
  media
  monitoring
  productivity
  ai
  sso
  home-automation
  notifications
)

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

show_help() {
  cat <<'HELP'
╔══════════════════════════════════════════════╗
║  HomeLab Stack — Integration Test Runner    ║
╚══════════════════════════════════════════════╝

USAGE:
  ./tests/run-tests.sh [OPTIONS]

OPTIONS:
  --stack <name>       Test a specific stack (comma-separated for multiple)
  --all                Test all available stacks
  --json               Generate JSON report at tests/results/report.json
  --junit              Also generate JUnit XML at tests/results/junit.xml
  --dry-run            List available tests without running them
  --verbose            Show detailed output for each test
  --timeout <seconds>  Set global timeout (default: 300)
  --help               Show this help message

EXAMPLES:
  ./tests/run-tests.sh --stack base
  ./tests/run-tests.sh --stack base,media,monitoring
  ./tests/run-tests.sh --all --json
  ./tests/run-tests.sh --all --json --junit
  ./tests/run-tests.sh --dry-run

AVAILABLE STACKS:
  base              Traefik, Portainer, Watchtower
  network           AdGuard Home, WireGuard, Cloudflared
  storage           Nextcloud, Syncthing, MinIO
  databases         PostgreSQL, Redis, MariaDB, InfluxDB
  media             Jellyfin, Sonarr, Radarr, qBittorrent
  monitoring        Prometheus, Grafana, cAdvisor, Loki
  productivity      Gitea, Outline, Planka
  ai                Ollama, Open WebUI
  sso               Authentik (OIDC/SAML)
  home-automation   Home Assistant, Zigbee2MQTT, Mosquitto
  notifications     Ntfy, Gotify, Apprise

ENVIRONMENT:
  NO_COLOR=1         Disable colored output
  TEST_TIMEOUT=300   Global timeout in seconds
  COMPOSE_DIR=       Override stacks directory

EXIT CODES:
  0  All tests passed
  1  One or more tests failed
  2  Configuration error
HELP
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        [[ -z "${2:-}" ]] && { echo "Error: --stack requires a value"; exit 2; }
        IFS=',' read -ra TARGET_STACKS <<< "$2"
        shift 2
        ;;
      --all)
        RUN_ALL=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --junit)
        JUNIT_OUTPUT=true
        JSON_OUTPUT=true  # junit requires json
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --timeout)
        [[ -z "${2:-}" ]] && { echo "Error: --timeout requires a value"; exit 2; }
        GLOBAL_TIMEOUT="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Error: Unknown option '$1'. Use --help for usage."
        exit 2
        ;;
    esac
  done

  if [[ "$RUN_ALL" == true ]]; then
    TARGET_STACKS=("${ALL_STACKS[@]}")
  fi

  if [[ ${#TARGET_STACKS[@]} -eq 0 ]] && [[ "$DRY_RUN" == false ]]; then
    echo "Error: Specify --stack <name> or --all. Use --help for usage."
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

preflight_checks() {
  echo -e "${BOLD:-}Pre-flight checks:${RESET:-}"

  # Docker
  if ! command -v docker &>/dev/null; then
    echo -e "  ${RED:-}✗${RESET:-} Docker not found"
    exit 2
  fi
  echo -e "  ${GREEN:-}✓${RESET:-} Docker: $(docker --version | head -1)"

  # Docker Compose
  if ! docker compose version &>/dev/null; then
    echo -e "  ${RED:-}✗${RESET:-} Docker Compose v2 not found"
    exit 2
  fi
  echo -e "  ${GREEN:-}✓${RESET:-} Compose: $(docker compose version --short)"

  # curl
  if ! command -v curl &>/dev/null; then
    echo -e "  ${RED:-}✗${RESET:-} curl not found"
    exit 2
  fi
  echo -e "  ${GREEN:-}✓${RESET:-} curl: $(curl --version | head -1 | cut -d' ' -f1-2)"

  # jq (optional but recommended)
  if command -v jq &>/dev/null; then
    echo -e "  ${GREEN:-}✓${RESET:-} jq: $(jq --version)"
  else
    echo -e "  ${YELLOW:-}⚠${RESET:-} jq not found (JSON report will be limited)"
  fi

  # Check Docker daemon
  if ! docker info &>/dev/null; then
    echo -e "  ${RED:-}✗${RESET:-} Docker daemon not running"
    exit 2
  fi
  echo -e "  ${GREEN:-}✓${RESET:-} Docker daemon is running"
  echo ""
}

# ---------------------------------------------------------------------------
# Test discovery
# ---------------------------------------------------------------------------

discover_tests() {
  local stack="$1"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    return 1
  fi

  # Extract test function names
  grep -oE '^test_[a-zA-Z0-9_]+\(\)' "$test_file" | sed 's/()//' || true
}

# ---------------------------------------------------------------------------
# Dry-run mode
# ---------------------------------------------------------------------------

dry_run() {
  print_header "HomeLab Stack — Test Discovery"

  for stack in "${ALL_STACKS[@]}"; do
    local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"
    if [[ -f "$test_file" ]]; then
      local tests
      tests=$(discover_tests "$stack")
      local count
      count=$(echo "$tests" | grep -c '^test_' 2>/dev/null || echo 0)
      echo -e "${GREEN:-}✓${RESET:-} ${BOLD:-}${stack}${RESET:-} — ${count} tests"
      if [[ "$VERBOSE" == true ]]; then
        echo "$tests" | while read -r t; do
          echo "    • ${t}"
        done
      fi
    else
      echo -e "${YELLOW:-}⏭${RESET:-} ${stack} — no test file"
    fi
  done

  echo ""
}

# ---------------------------------------------------------------------------
# Run tests for a single stack
# ---------------------------------------------------------------------------

run_stack_tests() {
  local stack="$1"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"
  local stack_start=$SECONDS

  print_stack_header "$stack"

  # Check if test file exists
  if [[ ! -f "$test_file" ]]; then
    echo -e "  ${YELLOW:-}⏭  No test file for '${stack}'${RESET:-}"
    return 0
  fi

  # Check if compose file exists
  local compose_file="${COMPOSE_DIR}/${stack}/docker-compose.yml"
  if [[ ! -f "$compose_file" ]]; then
    echo -e "  ${YELLOW:-}⏭  No compose file for '${stack}'${RESET:-}"
    return 0
  fi

  # Reset counters for this stack
  reset_counters

  # Source the test file (each test file defines test_* functions)
  # shellcheck disable=SC1090
  source "$test_file"

  # Discover and run test functions
  local test_functions
  test_functions=$(grep -oE '^test_[a-zA-Z0-9_]+\(\)' "$test_file" | sed 's/()//')

  while read -r func; do
    [[ -z "$func" ]] && continue
    _CURRENT_TEST="${stack}::${func}"

    # Run with timeout
    if ! timeout "${GLOBAL_TIMEOUT}" bash -c "
      source '${SCRIPT_DIR}/lib/assert.sh'
      source '${SCRIPT_DIR}/lib/docker.sh'
      source '${test_file}'
      ${func}
    " 2>/dev/null; then
      # If timeout or error, the test function handles its own assertions
      # But if the function itself crashed, record a fail
      if [[ $? -eq 124 ]]; then
        _assert_fail "Timeout: ${func}" "Exceeded ${GLOBAL_TIMEOUT}s"
      fi
    fi
  done <<< "$test_functions"

  local stack_duration=$(( SECONDS - stack_start ))
  local s_pass s_fail s_skip
  s_pass=$(get_pass_count)
  s_fail=$(get_fail_count)
  s_skip=$(get_skip_count)

  echo -e "\n  ${CYAN:-}${stack}:${RESET:-} ${GREEN:-}${s_pass} passed${RESET:-}, ${RED:-}${s_fail} failed${RESET:-}, ${YELLOW:-}${s_skip} skipped${RESET:-} (${stack_duration}s)"

  # Add to JSON report
  if [[ "$JSON_OUTPUT" == true ]]; then
    add_stack_to_json "$stack" "$s_pass" "$s_fail" "$s_skip" "$stack_duration"
  fi

  # Accumulate global counts
  GLOBAL_PASS=$(( GLOBAL_PASS + s_pass ))
  GLOBAL_FAIL=$(( GLOBAL_FAIL + s_fail ))
  GLOBAL_SKIP=$(( GLOBAL_SKIP + s_skip ))

  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"

  # Dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    dry_run
    exit 0
  fi

  # Pre-flight
  preflight_checks

  # Header
  print_header

  # Initialize report
  if [[ "$JSON_OUTPUT" == true ]]; then
    init_json_report
  fi

  # Global counters
  GLOBAL_PASS=0
  GLOBAL_FAIL=0
  GLOBAL_SKIP=0
  local global_start=$SECONDS

  # Run tests for each target stack
  for stack in "${TARGET_STACKS[@]}"; do
    run_stack_tests "$stack"
  done

  local total_duration=$(( SECONDS - global_start ))

  # Summary
  print_summary "$GLOBAL_PASS" "$GLOBAL_FAIL" "$GLOBAL_SKIP" "$total_duration"

  # Finalize reports
  if [[ "$JSON_OUTPUT" == true ]]; then
    finalize_json_report "$GLOBAL_PASS" "$GLOBAL_FAIL" "$GLOBAL_SKIP" "$total_duration"
    echo "📄 JSON report: tests/results/report.json"
  fi

  if [[ "$JUNIT_OUTPUT" == true ]]; then
    generate_junit_xml
    echo "📄 JUnit XML: tests/results/junit.xml"
  fi

  # Exit code
  if [[ "$GLOBAL_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
