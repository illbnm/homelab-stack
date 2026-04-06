#!/bin/bash
# assert.sh - 断言库 for HomeLab Stack Integration Tests
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_SKIPPED=0
TEST_RESULTS=()

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: assert_eq - Expected: $expected, Got: $actual")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: assert_eq - Expected: $expected, Got: $actual - $msg")
        echo -e "${RED}❌ FAIL${NC} [assert_eq] Expected: $expected, Actual: $actual"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    if [[ -n "$value" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: assert_not_empty - Value is empty - $msg")
        echo -e "${RED}❌ FAIL${NC} [assert_not_empty] Value is empty"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local msg="${3:-}"
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: assert_exit_code - Expected: $expected_code, Got: $actual_code - $msg")
        echo -e "${RED}❌ FAIL${NC} [assert_exit_code] Expected: $expected_code, Actual: $actual_code"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

assert_container_running() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [[ "$status" == "running" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: Container $container is running")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: Container $container status: ${status:-not found}")
        echo -e "${RED}❌ FAIL${NC} Container $container status: ${status:-not found}"
        return 1
    fi
}

assert_container_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        if [[ "$health" == "healthy" ]]; then
            ((ASSERTIONS_PASSED++))
            TEST_RESULTS+=("PASS: Container $container is healthy")
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            ((ASSERTIONS_FAILED++))
            TEST_RESULTS+=("FAIL: Container $container is unhealthy")
            echo -e "${RED}❌ FAIL${NC} Container $container is unhealthy"
            return 1
        fi
        sleep 5
        ((elapsed+=5))
    done
    ((ASSERTIONS_FAILED++))
    TEST_RESULTS+=("FAIL: Timeout waiting for $container to be healthy")
    echo -e "${RED}❌ FAIL${NC} Timeout waiting for $container"
    return 1
}

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: $url returned 200")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: $url returned $http_code")
        echo -e "${RED}❌ FAIL${NC} $url returned $http_code"
        return 1
    fi
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    if echo "$response" | grep -q "$pattern"; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: $url matches pattern '$pattern'")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: $url does not match pattern '$pattern'")
        echo -e "${RED}❌ FAIL${NC} $url does not match pattern '$pattern'"
        return 1
    fi
}

assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: JSON $jq_path = $expected")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: JSON $jq_path - Expected: $expected, Got: $actual")
        echo -e "${RED}❌ FAIL${NC} [JSON] $jq_path - Expected: $expected, Got: $actual"
        return 1
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local result=$(echo "$json" | jq "$jq_path" 2>/dev/null)
    if [[ "$result" != "null" && -n "$result" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: JSON key exists at $jq_path")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: JSON key not found at $jq_path")
        echo -e "${RED}❌ FAIL${NC} [JSON] Key not found: $jq_path"
        return 1
    fi
}

assert_no_errors() {
    local json="$1"
    local errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -z "$errors" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: No errors in response")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: Errors found: $errors")
        echo -e "${RED}❌ FAIL${NC} Errors found: $errors"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: File exists: $file")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: File not found: $file")
        echo -e "${RED}❌ FAIL${NC} File not found: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: File $file contains '$pattern'")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: File $file does not contain '$pattern'")
        echo -e "${RED}❌ FAIL${NC} File $file does not contain '$pattern'"
        return 1
    fi
}

assert_compose_valid() {
    local compose_file="$1"
    local output=$(docker compose -f "$compose_file" config --quiet 2>&1)
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: Compose file valid: $compose_file")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: Compose file invalid: $compose_file - $output")
        echo -e "${RED}❌ FAIL${NC} Compose file invalid: $compose_file"
        echo "  $output"
        return 1
    fi
}

assert_no_latest_tags() {
    local dir="$1"
    local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    if [[ "$count" -eq 0 ]]; then
        ((ASSERTIONS_PASSED++))
        TEST_RESULTS+=("PASS: No :latest tags found in $dir")
        return 0
    else
        ((ASSERTIONS_FAILED++))
        TEST_RESULTS+=("FAIL: Found $count :latest tags in $dir")
        echo -e "${RED}❌ FAIL${NC} Found $count :latest tags in $dir"
        return 1
    fi
}

print_summary() {
    local passed=$1
    local failed=$2
    local skipped=$3
    local total=$((passed + failed + skipped))
    echo ""
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    echo -e "Results: ${GREEN}✅ $passed passed${NC}, ${RED}❌ $failed failed${NC}, ${YELLOW}⏭️ $skipped skipped${NC}"
    echo -e "Total: $total"
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    [[ $failed -gt 0 ]] && return 1
    return 0
}

generate_json_report() {
    local output_dir="$1"
    local stack_name="$2"
    mkdir -p "$output_dir"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$output_dir/report.json" << EOF
{
  "timestamp": "$timestamp",
  "stack": "$stack_name",
  "results": {
    "passed": $ASSERTIONS_PASSED,
    "failed": $ASSERTIONS_FAILED,
    "skipped": $ASSERTIONS_SKIPPED,
    "total": $((ASSERTIONS_PASSED + ASSERTIONS_FAILED + ASSERTIONS_SKIPPED))
  },
  "details": $(printf '%s\n' "${TEST_RESULTS[@]}" | jq -R . | jq -s .)
}
EOF
    echo -e "${CYAN}📄 JSON report written to: $output_dir/report.json${NC}"
}

reset_counters() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_SKIPPED=0
    TEST_RESULTS=()
}

export -f assert_eq assert_not_empty assert_exit_code assert_container_running assert_container_healthy
export -f assert_http_200 assert_http_response assert_json_value assert_json_key_exists assert_no_errors
export -f assert_file_exists assert_file_contains assert_compose_valid assert_no_latest_tags
export -f print_summary generate_json_report reset_counters
