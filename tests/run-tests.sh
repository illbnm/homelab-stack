#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — homelab-stack Integration Test Runner
# Usage:
#   ./run-tests.sh                  # run all tests
#   ./run-tests.sh --all            # alias for above
#   ./run-tests.sh --stack base     # run one stack's tests
#   ./run-tests.sh --stacks base,ai,network   # comma-separated
#   ./run-tests.sh --e2e            # run e2e tests only
#   ./run-tests.sh --no-colour      # disable colour output
#   ./run-tests.sh --json           # also write JSON report
#   ./run-tests.sh --help
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$SCRIPT_DIR"

# ── defaults ───────────────────────────────────────────────────────────────────
STACKS="base,media,storage,monitoring,network,productivity,ai,sso,databases,notifications"
RUN_E2E=false
NO_COLOUR=false
JSON_OUTPUT=false

# ── colours (can be disabled) ─────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "$NO_COLOUR" == "false" ]]; then
  RED='\033[0;31m';   GREEN='\033[0;32m';  YELLOW='\033[1;33m'
  BLUE='\033[0;34m';  CYAN='\033[0;36m';  BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ── helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
die()     { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

usage() {
  cat <<EOF
${BOLD}homelab-stack test runner${NC}

${BOLD}Usage:${NC}
  $0 [options]

${BOLD}Options:${NC}
  --all               Run all stack tests (default)
  --stack <name>      Run tests for a specific stack
  --stacks <s1,s2>    Run tests for multiple stacks (comma-separated)
  --e2e               Run end-to-end tests only
  --no-colour         Disable colour output
  --json              Write JSON report to /tmp/homelab-test-report.json
  --help              Show this message

${BOLD}Examples:${NC}
  $0                          # all stacks
  $0 --stack base             # base infra only
  $0 --stacks ai,network     # AI + network
  $0 --e2e                    # e2e tests only
  $0 --stack base --json      # base + JSON output

${BOLD}Stacks:${NC}
  base, media, storage, monitoring, network,
  productivity, ai, sso, databases, notifications
EOF
}

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)            STACKS="base,media,storage,monitoring,network,productivity,ai,sso,databases,notifications" ;;
    --stack)          STACKS="${2:-}"; shift ;;
    --stacks)        STACKS="${2:-}"; shift ;;
    --e2e)           RUN_E2E=true ;;
    --no-colour)     NO_COLOUR=true; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC='' ;;
    --json)          JSON_OUTPUT=true ;;
    --help|-h)       usage; exit 0 ;;
    *)               die "Unknown option: $1 (use --help)" ;;
  esac
  shift
done

# ── pre-flight ────────────────────────────────────────────────────────────────
info "Loading .env from $ROOT_DIR"
[[ -f "$ROOT_DIR/.env" ]] && export $(grep -v '^#' "$ROOT_DIR/.env" | xargs) 2>/dev/null || true

info "Checking Docker availability..."
docker info &>/dev/null || die "Docker is not running — start Docker Desktop and retry"

info "Docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)"
info "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo unknown)"

# ── colour re-init after no-colour flag ──────────────────────────────────────
banner() {
  echo ""
  echo -e "${BOLD}╔$(printf '═%.0s' {1..60})╗${NC}"
  printf "${BOLD}║ %-60s ║${NC}\n" "$1"
  echo -e "${BOLD}╚$(printf '═%.0s' {1..60})╝${NC}"
}

# ── run a test file ───────────────────────────────────────────────────────────
run_test_file() {
  local file="$1"
  local name
  name=$(basename "$file" .test.sh)
  echo ""
  echo -e "${CYAN}▶ $name${NC}"

  local rc=0
  bash "$file" || rc=$?

  if [[ $rc -eq 0 ]]; then
    echo -e "  ${GREEN}✓ $name passed${NC}"
  else
    echo -e "  ${RED}✗ $name failed (exit $rc)${NC}"
  fi
  return $rc
}

# ── main ──────────────────────────────────────────────────────────────────────
banner "homelab-stack test suite"
echo ""
echo "  Root:   $ROOT_DIR"
echo "  Domain: ${DOMAIN:-localhost}"
echo "  Stacks: $STACKS"
echo "  E2E:    $RUN_E2E"

# Parse stacks into array
IFS=',' read -ra STACK_ARRAY <<< "$STACKS"

TOTAL_FAIL=0

# Run stack tests
if [[ ${#STACK_ARRAY[@]} -gt 0 ]] && [[ "${STACK_ARRAY[0]}" != "" ]]; then
  banner "Stack Tests"
  for stack in "${STACK_ARRAY[@]}"; do
    stack="${stack// /}"  # trim whitespace
    [[ -z "$stack" ]] && continue

    test_file="$TESTS_DIR/stacks/${stack}.test.sh"
    if [[ -f "$test_file" ]]; then
      run_test_file "$test_file" || TOTAL_FAIL=$((TOTAL_FAIL+1))
    else
      warn "No test file for stack: $stack (skipping)"
    fi
  done
fi

# Run E2E tests
if [[ "$RUN_E2E" == "true" ]]; then
  banner "End-to-End Tests"
  for e2e_file in "$TESTS_DIR"/e2e/*.test.sh; do
    [[ -f "$e2e_file" ]] || continue
    run_test_file "$e2e_file" || TOTAL_FAIL=$((TOTAL_FAIL+1))
  done
fi

# ── summary ───────────────────────────────────────────────────────────────────
banner "Results"
if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}All tests passed ✓${NC}"
  echo ""
  echo "  Run individual stacks with:"
  echo "    $0 --stack base"
  echo "    $0 --stack ai"
  echo "    $0 --e2e"
  echo ""
  exit 0
else
  echo -e "  ${RED}$TOTAL_FAIL test suite(s) had failures${NC}"
  echo ""
  exit 1
fi