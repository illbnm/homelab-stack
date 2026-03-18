#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
#
# Runs integration tests for one or all stacks.
#
# Usage:
#   ./run-tests.sh --stack base          # Test a single stack
#   ./run-tests.sh --stack base,storage  # Test multiple stacks
#   ./run-tests.sh --all                 # Test all available stacks
#   ./run-tests.sh --help                # Show help
#
# Options:
#   --stack <name>    Run tests for specific stack(s) (comma-separated)
#   --all             Run all available stack tests
#   --json            Only output JSON report (no terminal colors)
#   --ci              CI mode: non-interactive, JSON output, exit code
#   --help            Show this help message
#
# Dependencies: bash 4+, curl, jq, docker, docker compose v2
# =============================================================================
set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"

# Available stack tests (order matters: base first, then dependencies)
AVAILABLE_STACKS=(
  "base"
  "databases"
  "storage"
  "media"
  "network"
  "productivity"
  "ai"
  "sso"
  "notifications"
  "monitoring"
)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
show_help() {
  cat << 'HELPEOF'
HomeLab Stack — Integration Test Runner

USAGE:
  ./run-tests.sh [OPTIONS]

OPTIONS:
  --stack <name>    Run tests for specific stack(s)
                    Comma-separated for multiple: --stack base,databases
  --all             Run all available stack tests
  --json            JSON-only output (suppress terminal formatting)
  --ci              CI mode (implies --json, sets exit code)
  --help            Show this help message

AVAILABLE STACKS:
  base              Base infrastructure (Traefik, Portainer, Watchtower, Socket Proxy)
  databases         Database layer (PostgreSQL, Redis, MariaDB, pgAdmin, Redis Commander)
  storage           Storage (Nextcloud, MinIO, FileBrowser, Syncthing)
  media             Media stack (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent)
  network           Network (AdGuard Home, WireGuard, Unbound, DDNS)
  productivity      Productivity (Gitea, Vaultwarden, Outline, BookStack)
  ai                AI stack (Ollama, Open WebUI, Stable Diffusion)
  sso               SSO (Authentik)
  notifications     Notifications (Gotify, ntfy)
  monitoring        Observability (Prometheus, Grafana, Loki)

EXAMPLES:
  ./run-tests.sh --stack base
  ./run-tests.sh --stack base,databases,storage
  ./run-tests.sh --all
  ./run-tests.sh --all --json

EXIT CODES:
  0   All tests passed
  1   One or more tests failed
  2   Invalid arguments or missing dependencies
HELPEOF
}

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
check_deps() {
  local missing=()

  for cmd in bash curl jq docker; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  # Check docker compose v2
  if ! docker compose version > /dev/null 2>&1; then
    missing+=("docker-compose-v2")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing dependencies: ${missing[*]}" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Run a test function with timing and error capture
# ---------------------------------------------------------------------------
run_test() {
  local stack="$1"
  local test_name="$2"
  local test_func="$3"

  _CURRENT_STACK="${stack}"
  _CURRENT_TEST="${test_name}"
  _TEST_START_TIME=$(date +%s%N 2>/dev/null || date +%s)
  _LAST_EXIT_CODE=0

  # Run the test function, capturing exit code
  "${test_func}" || _LAST_EXIT_CODE=$?
}

# ---------------------------------------------------------------------------
# Run all tests for a stack
# ---------------------------------------------------------------------------
run_stack_tests() {
  local stack="$1"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

  if [[ ! -f "${test_file}" ]]; then
    echo "WARNING: No test file found for stack '${stack}' (expected ${test_file})" >&2
    return
  fi

  report_stack_header "${stack}"

  # Source the test file (defines test_* functions)
  # shellcheck source=/dev/null
  source "${test_file}"

  # Discover and run all test_* functions defined in the file
  local funcs
  funcs=$(declare -F | awk '{print $3}' | grep "^test_${stack}_" || true)

  if [[ -z "${funcs}" ]]; then
    echo "  (no tests defined for ${stack})" >&2
    return
  fi

  local test_name
  for func in ${funcs}; do
    # Convert function name to readable test name
    # test_base_traefik_running -> traefik running
    test_name="${func#"test_${stack}_"}"
    test_name="${test_name//_/ }"

    run_test "${stack}" "${test_name}" "${func}"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local stacks_to_run=()
  local json_only=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        shift
        IFS=',' read -ra stacks_to_run <<< "${1:-}"
        ;;
      --all)
        stacks_to_run=("${AVAILABLE_STACKS[@]}")
        ;;
      --json)
        json_only=true
        ;;
      --ci)
        json_only=true
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        show_help
        exit 2
        ;;
    esac
    shift
  done

  # Must specify at least one stack
  if [[ ${#stacks_to_run[@]} -eq 0 ]]; then
    echo "ERROR: No stacks specified. Use --stack <name> or --all" >&2
    echo ""
    show_help
    exit 2
  fi

  # Check dependencies
  check_deps

  # Export json_only so report.sh can use it
  export _JSON_ONLY="${json_only}"

  # Run tests
  report_header

  for stack in "${stacks_to_run[@]}"; do
    run_stack_tests "${stack}"
  done

  # Print summary and exit
  report_summary
  exit $?
}

main "$@"
