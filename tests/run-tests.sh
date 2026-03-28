#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack Integration Tests — Main Runner
# =============================================================================
# Usage:
#   ./run-tests.sh              # Run all tests
#   ./run-tests.sh --stack base # Run specific stack tests
#   ./run-tests.sh --all        # Run all stack tests
#   ./run-tests.sh --e2e         # Run E2E tests only
#   ./run-tests.sh --help        # Show help
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
TESTS_LIB="$SCRIPT_DIR/lib"
RESULTS_DIR="$SCRIPT_DIR/results"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Source report lib for banner
source "$TESTS_LIB/report.sh"

# Global counters
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
TOTAL_DURATION=0

# ---- Help ----
show_help() {
    cat << EOF
${BOLD}HomeLab Stack — Integration Test Runner${NC}

${BOLD}USAGE${NC}
  $0 [OPTIONS]

${BOLD}OPTIONS${NC}
  --stack <name>    Run tests for specific stack (base, media, sso, etc.)
  --all             Run all stack tests
  --e2e             Run E2E tests only
  --json            Output JSON report
  --help            Show this help

${BOLD}STACKS${NC}
  base              Base infrastructure (Traefik, Portainer, Watchtower)
  sso               SSO stack (Authentik)
  media             Media stack (Jellyfin, Sonarr, Radarr, qBittorrent)
  monitoring        Monitoring stack (Prometheus, Grafana, Loki)
  databases         Databases (PostgreSQL, Redis, MariaDB)
  storage           Storage (Nextcloud, MinIO, Filebrowser)
  network           Network (AdGuard, Nginx-Proxy-Manager, WireGuard)
  productivity      Productivity (Gitea, Vaultwarden)
  ai                AI stack (Ollama, Open WebUI)
  home-automation   Home automation (Home Assistant, Node-RED)
  notifications     Notifications (ntfy)
  dashboard         Dashboard (Homepage)

${BOLD}EXAMPLES${NC}
  $0 --stack base          Run base infrastructure tests
  $0 --all                 Run all stack tests
  $0 --stack media --stack sso  Run media and SSO tests
  $0 --e2e                  Run E2E tests

${BOLD}EXIT CODES${NC}
  0   All tests passed
  1   One or more tests failed
  2   Invalid arguments

EOF
}

# ---- Header Banner ----
print_banner() {
    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC}  HomeLab Stack — Integration Tests${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
}

# ---- Run a test file ----
run_test_file() {
    local test_file="$1"
    local json_output="${2:-}"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}Test file not found: $test_file${NC}"
        return 1
    fi

    chmod +x "$test_file"

    if [[ -n "$json_output" ]]; then
        "$test_file" 2>&1 | tee /tmp/test_output_$$.txt
    else
        "$test_file" 2>&1
    fi
}

# ---- Run stack tests ----
run_stack_tests() {
    local stack="$1"
    local json_output="${2:-}"

    echo -e "${CYAN}Running $stack stack tests...${NC}"

    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}No test file for stack: $stack${NC}"
        return 0
    fi

    chmod +x "$test_file"

    if [[ -n "$json_output" ]]; then
        REPORT_FILE="$RESULTS_DIR/${stack}_report.json" "$test_file" 2>&1
    else
        "$test_file" 2>&1
    fi
}

# ---- Run all stack tests ----
run_all_stack_tests() {
    local json_output="${1:-}"

    local stacks=(base sso media monitoring databases storage network productivity ai home-automation notifications dashboard)

    for stack in "${stacks[@]}"; do
        if [[ -f "$SCRIPT_DIR/stacks/${stack}.test.sh" ]]; then
            run_stack_tests "$stack" "$json_output"
            echo ""
        fi
    done
}

# ---- Run E2E tests ----
run_e2e_tests() {
    local json_output="${1:-}"

    echo -e "${CYAN}Running E2E tests...${NC}"
    echo ""

    local e2e_tests=(
        "$SCRIPT_DIR/e2e/sso-flow.test.sh"
        "$SCRIPT_DIR/e2e/backup-restore.test.sh"
    )

    for test_file in "${e2e_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            chmod +x "$test_file"
            "$test_file" 2>&1
            echo ""
        fi
    done
}

# ---- Parse args ----
STACK=""
RUN_ALL=false
RUN_E2E=false
JSON_OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            STACK="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --e2e)
            RUN_E2E=true
            shift
            ;;
        --json)
            JSON_OUTPUT="yes"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 2
            ;;
    esac
done

# ---- Main ----
main() {
    mkdir -p "$RESULTS_DIR"

    print_banner

    if [[ "$RUN_ALL" == "true" ]]; then
        run_all_stack_tests "$JSON_OUTPUT"
        run_e2e_tests "$JSON_OUTPUT"
    elif [[ -n "$STACK" ]]; then
        run_stack_tests "$STACK" "$JSON_OUTPUT"
    elif [[ "$RUN_E2E" == "true" ]]; then
        run_e2e_tests "$JSON_OUTPUT"
    else
        # Default: run base stack
        run_stack_tests "base" "$JSON_OUTPUT"
    fi
}

main
