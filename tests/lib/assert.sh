#!/bin/bash
# =============================================================================
# Assertion Library for HomeLab Stack Tests
# =============================================================================

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# -----------------------------------------------------------------------------
# Test framework functions
# -----------------------------------------------------------------------------
describe() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

it() {
    echo -e "  ▶ $1"
}

# -----------------------------------------------------------------------------
# Assertion functions
# -----------------------------------------------------------------------------
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values are not equal}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_eq: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_eq: $message (expected: '$expected', got: '$actual') at line $line"
        return 1
    fi
}

assert_ne() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ "$expected" != "$actual" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_ne: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_ne: $message (values should differ) at line $line"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String does not contain substring}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++))
        log_success "assert_contains: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_contains: $message (needle: '$needle') at line $line"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ "$haystack" != *"$needle"* ]]; then
        ((TESTS_PASSED++))
        log_success "assert_not_contains: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_not_contains: $message (should not contain: '$needle') at line $line"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ -f "$file" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_file_exists: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_file_exists: $message (file: '$file') at line $line"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ -d "$dir" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_dir_exists: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_dir_exists: $message (dir: '$dir') at line $line"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# HTTP/Network assertion functions
# -----------------------------------------------------------------------------
assert_http_200() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP request should return 200}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_http_200: $message (URL: $url)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_http_200: $message (expected: 200, got: $http_code, URL: $url) at line $line"
        return 1
    fi
}

assert_http_2xx() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP request should return 2xx}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
        ((TESTS_PASSED++))
        log_success "assert_http_2xx: $message (code: $http_code, URL: $url)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_http_2xx: $message (expected: 2xx, got: $http_code, URL: $url) at line $line"
        return 1
    fi
}

assert_http_3xx() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP request should return 3xx}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" =~ ^3[0-9]{2}$ ]]; then
        ((TESTS_PASSED++))
        log_success "assert_http_3xx: $message (code: $http_code, URL: $url)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_http_3xx: $message (expected: 3xx, got: $http_code, URL: $url) at line $line"
        return 1
    fi
}

assert_http_4xx() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP request should return 4xx}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" =~ ^4[0-9]{2}$ ]]; then
        ((TESTS_PASSED++))
        log_success "assert_http_4xx: $message (code: $http_code, URL: $url)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_http_4xx: $message (expected: 4xx, got: $http_code, URL: $url) at line $line"
        return 1
    fi
}

assert_http_connection() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP endpoint should be reachable}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" != "000" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_http_connection: $message (code: $http_code, URL: $url)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_http_connection: $message (connection failed, URL: $url) at line $line"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker/container assertion functions
# -----------------------------------------------------------------------------
assert_container_running() {
    local container_name="$1"
    local message="${2:-Container should be running}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local status
    status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null || echo "false")

    if [[ "$status" == "true" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_container_running: $message (container: $container_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_container_running: $message (container: $container_name) at line $line"
        return 1
    fi
}

assert_container_stopped() {
    local container_name="$1"
    local message="${2:-Container should be stopped}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local status
    status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null || echo "false")

    if [[ "$status" != "true" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_container_stopped: $message (container: $container_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_container_stopped: $message (container: $container_name) at line $line"
        return 1
    fi
}

assert_container_healthy() {
    local container_name="$1"
    local message="${2:-Container health check should pass}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

    if [[ "$health" == "healthy" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_container_healthy: $message (container: $container_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_container_healthy: $message (container: $container_name, status: $health) at line $line"
        return 1
    fi
}

assert_container_image() {
    local container_name="$1"
    local expected_image="$2"
    local message="${3:-Container should use correct image}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local actual_image
    actual_image=$(docker inspect -f '{{.Config.Image}}' "$container_name" 2>/dev/null || echo "")

    if [[ "$actual_image" == "$expected_image" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_container_image: $message (container: $container_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_container_image: $message (expected: $expected_image, got: $actual_image) at line $line"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker Compose assertion functions
# -----------------------------------------------------------------------------
assert_docker_compose_valid() {
    local compose_file="$1"
    local message="${2:-Docker Compose file should be valid}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local result
    result=$(docker compose -f "$compose_file" config --quiet 2>&1)

    if [[ $? -eq 0 ]]; then
        ((TESTS_PASSED++))
        log_success "assert_docker_compose_valid: $message (file: $compose_file)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_docker_compose_valid: $message (file: $compose_file, error: $result) at line $line"
        return 1
    fi
}

assert_service_exists() {
    local compose_file="$1"
    local service_name="$2"
    local message="${3:-Service should exist in compose file}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    local services
    services=$(docker compose -f "$compose_file" config --services 2>/dev/null || echo "")

    if echo "$services" | grep -q "^${service_name}$"; then
        ((TESTS_PASSED++))
        log_success "assert_service_exists: $message (service: $service_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_service_exists: $message (service: $service_name not found) at line $line"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Network assertion functions
# -----------------------------------------------------------------------------
assert_docker_network_exists() {
    local network_name="$1"
    local message="${2:-Docker network should exist}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if docker network inspect "$network_name" >/dev/null 2>&1; then
        ((TESTS_PASSED++))
        log_success "assert_docker_network_exists: $message (network: $network_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_docker_network_exists: $message (network: $network_name) at line $line"
        return 1
    fi
}

assert_service_can_reach() {
    local from_container="$1"
    local to_host="$2"
    local message="${3:-Service should be reachable}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if docker exec "$from_container" wget -q -O /dev/null --timeout=5 "$to_host" 2>/dev/null; then
        ((TESTS_PASSED++))
        log_success "assert_service_can_reach: $message (from: $from_container, to: $to_host)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_service_can_reach: $message (from: $from_container, to: $to_host) at line $line"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Config validation functions
# -----------------------------------------------------------------------------
assert_env_var_set() {
    local var_name="$1"
    local message="${2:-Environment variable should be set}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if [[ -n "${!var_name}" ]]; then
        ((TESTS_PASSED++))
        log_success "assert_env_var_set: $message (var: $var_name)"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "assert_env_var_set: $message (var: $var_name not set or empty) at line $line"
        return 1
    fi
}

assert_yaml_valid() {
    local yaml_file="$1"
    local message="${2:-YAML file should be valid}"
    local line="${BASH_LINENO[0]}"

    ((TESTS_RUN++))

    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            ((TESTS_PASSED++))
            log_success "assert_yaml_valid: $message (file: $yaml_file)"
            return 0
        else
            ((TESTS_FAILED++))
            log_error "assert_yaml_valid: $message (file: $yaml_file is invalid) at line $line"
            return 1
        fi
    else
        # Fallback: just check if file is readable
        if [[ -r "$yaml_file" ]]; then
            ((TESTS_PASSED++))
            log_success "assert_yaml_valid: $message (file: $yaml_file)"
            return 0
        else
            ((TESTS_FAILED++))
            log_error "assert_yaml_valid: $message (file: $yaml_file not readable) at line $line"
            return 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# Test result summary
# -----------------------------------------------------------------------------
print_summary() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Export functions for use in subshells
export -f log_info log_success log_error log_warn
export -f describe it
export -f assert_eq assert_ne assert_contains assert_not_contains
export -f assert_file_exists assert_dir_exists
export -f assert_http_200 assert_http_2xx assert_http_3xx assert_http_4xx assert_http_connection
export -f assert_container_running assert_container_stopped assert_container_healthy assert_container_image
export -f assert_docker_compose_valid assert_service_exists
export -f assert_docker_network_exists assert_service_can_reach
export -f assert_env_var_set assert_yaml_valid
export -f print_summary