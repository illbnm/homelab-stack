#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — Network Connectivity Detection for Docker Registries
# =============================================================================
# Tests connectivity to various Docker registries and services to help
# determine if CN mirror acceleration is needed.
#
# Usage:
#   ./check-connectivity.sh [--quick] [--verbose] [--json]
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
MIRROR_CONFIG="$PROJECT_ROOT/config/cn-mirrors.yml"
QUICK_MODE="${QUICK_MODE:-false}"
VERBOSE="${VERBOSE:-false}"
OUTPUT_JSON="${OUTPUT_JSON:-false}"

# Test results storage
declare -A TEST_RESULTS
declare -A TEST_TIMES

# Logging functions
log_info()  { [[ "$OUTPUT_JSON" != "true" ]] && echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { [[ "$OUTPUT_JSON" != "true" ]] && echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { [[ "$OUTPUT_JSON" != "true" ]] && echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { [[ "$OUTPUT_JSON" != "true" ]] && echo -e "\n${BLUE}${BOLD}==>${NC} $*"; }
log_debug() { [[ "$VERBOSE" == "true" ]] && [[ "$OUTPUT_JSON" != "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# Test HTTP/HTTPS endpoint
test_endpoint() {
  local name="$1"
  local url="$2"
  local timeout="${3:-5}"

  local start_time
  start_time=$(date +%s%N)

  local http_code
  local response_time_ms

  # Use curl to test connectivity
  if http_code=$(curl -sf --connect-timeout "$timeout" --max-time "$((timeout * 2))" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
    local end_time
    end_time=$(date +%s%N)
    response_time_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$http_code" =~ ^(200|401|403|404)$ ]]; then
      # These status codes indicate server is reachable
      TEST_RESULTS["$name"]="OK"
      TEST_TIMES["$name"]="$response_time_ms"
      return 0
    else
      TEST_RESULTS["$name"]="ERROR"
      TEST_TIMES["$name"]="$response_time_ms"
      return 1
    fi
  else
    TEST_RESULTS["$name"]="FAIL"
    TEST_TIMES["$name"]="0"
    return 1
  fi
}

# Test Docker registry v2 API
test_registry() {
  local name="$1"
  local registry_url="$2"

  log_debug "Testing registry: $name ($registry_url)"

  # Test v2 API endpoint
  local v2_url="$registry_url/v2/"

  if test_endpoint "$name" "$v2_url" 5; then
    return 0
  else
    return 1
  fi
}

# Test if behind GFW (Great Firewall of China)
test_gfw() {
  log_step "Testing network environment"

  # Test common blocked sites to detect if in China
  local gfw_indicators=(
    "www.google.com"
    "www.youtube.com"
  )

  local blocked_count=0
  local total=${#gfw_indicators[@]}

  for domain in "${gfw_indicators[@]}"; do
    if ! timeout 3 curl -sf "https://$domain" &>/dev/null; then
      ((blocked_count++))
      log_debug "Blocked: $domain"
    fi
  done

  # If most are blocked, likely in China
  if [[ $blocked_count -ge $((total / 2)) ]]; then
    log_warn "Detected: Likely in mainland China (GFW detected)"
    return 0
  else
    log_info "Detected: International network (no GFW detected)"
    return 1
  fi
}

# Test CN mirror connectivity
test_cn_mirrors() {
  log_step "Testing CN mirror availability"

  local mirrors=(
    "Docker Hub (DaoCloud):https://docker.m.daocloud.io"
    "GCR (DaoCloud):https://gcr.m.daocloud.io"
    "GHCR (DaoCloud):https://ghcr.m.daocloud.io"
  )

  for mirror in "${mirrors[@]}"; do
    local name="${mirror%%:*}"
    local url="${mirror#*:}"

    if test_endpoint "$name" "$url/v2/" 5; then
      log_info "✓ $name (available)"
    else
      log_warn "✗ $name (unavailable)"
    fi
  done
}

# Run all connectivity tests
run_all_tests() {
  log_step "Running connectivity tests"

  # Core registries
  log_info "Testing core Docker registries..."
  test_registry "Docker Hub" "https://registry-1.docker.io"
  test_registry "GitHub Container Registry" "https://ghcr.io"
  test_registry "Google Container Registry" "https://gcr.io"
  test_registry "Quay.io" "https://quay.io"

  # GitHub services
  log_info "Testing GitHub services..."
  test_endpoint "GitHub" "https://github.com" 5
  test_endpoint "GitHub API" "https://api.github.com" 5

  # Quick mode - skip additional tests
  if [[ "$QUICK_MODE" == "true" ]]; then
    return
  fi

  # CN mirrors if GFW detected
  if test_gfw; then
    test_cn_mirrors
  fi
}

# Print test results
print_results() {
  log_step "Test Results"

  local ok_count=0
  local fail_count=0
  local error_count=0

  # Sort results
  local sorted_names
  sorted_names=$(echo "${!TEST_RESULTS[@]}" | tr ' ' '\n' | sort)

  printf "\n%-35s %-10s %s\n" "SERVICE" "STATUS" "RESPONSE TIME"
  printf "%-35s %-10s %s\n" "-------" "------" "-------------"

  for name in $sorted_names; do
    local status="${TEST_RESULTS[$name]}"
    local time="${TEST_TIMES[$name]}"

    local status_str
    local color

    case "$status" in
      OK)
        status_str="✓ OK"
        color="$GREEN"
        ((ok_count++))
        ;;
      FAIL)
        status_str="✗ FAIL"
        color="$RED"
        ((fail_count++))
        ;;
      ERROR)
        status_str="⚠ ERROR"
        color="$YELLOW"
        ((error_count++))
        ;;
    esac

    printf "${color}%-35s %-10s${NC} %sms\n" "$name" "$status_str" "$time"
  done

  echo
  echo "Summary: ${GREEN}$ok_count OK${NC}, ${YELLOW}$error_count ERROR${NC}, ${RED}$fail_count FAIL${NC}"
}

# Generate recommendations
generate_recommendations() {
  log_step "Recommendations"

  local docker_hub_ok="${TEST_RESULTS[Docker Hub]:-FAIL}"
  local gcr_ok="${TEST_RESULTS[Google Container Registry]:-FAIL}"
  local ghcr_ok="${TEST_RESULTS[GitHub Container Registry]:-FAIL}"

  # Check if any critical registries failed
  if [[ "$docker_hub_ok" == "FAIL" || "$gcr_ok" == "FAIL" || "$ghcr_ok" == "FAIL" ]]; then
    log_warn "Some registries are unreachable. Recommendations:"
    echo
    echo "  1. Enable CN mirror acceleration:"
    echo "     sudo ./scripts/setup-cn-mirrors.sh"
    echo
    echo "  2. Localize images to use mirrors:"
    echo "     ./scripts/localize-images.sh --cn --all"
    echo
  else
    log_info "All critical registries are accessible"
    log_info "CN mirror acceleration not required but can still improve performance"
  fi
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 [OPTIONS]

${BOLD}Options:${NC}
  --quick       Quick mode - test only critical endpoints
  --verbose     Enable verbose output
  --json        Output results in JSON format
  -h, --help    Show this help message

${BOLD}Examples:${NC}
  # Run full connectivity test
  $0

  # Quick test (critical endpoints only)
  $0 --quick

${BOLD}Exit Codes:${NC}
  0 - All critical services accessible
  1 - Some critical services unreachable
EOF
}

# Main entry point
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quick)
        QUICK_MODE="true"
        shift
        ;;
      --verbose)
        VERBOSE="true"
        shift
        ;;
      --json)
        OUTPUT_JSON="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Run tests
  run_all_tests

  # Output results
  if [[ "$OUTPUT_JSON" != "true" ]]; then
    print_results

    # Generate recommendations if not in quick mode
    if [[ "$QUICK_MODE" != "true" ]]; then
      generate_recommendations
    fi
  fi

  # Exit with appropriate code
  local has_critical_failure=false
  for name in "${!TEST_RESULTS[@]}"; do
    if [[ "${TEST_RESULTS[$name]}" == "FAIL" ]]; then
      # Check if this is a critical service
      case "$name" in
        "Docker Hub"|"GitHub"|"GitHub API")
          has_critical_failure=true
          ;;
      esac
    fi
  done

  if [[ "$has_critical_failure" == "true" ]]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
