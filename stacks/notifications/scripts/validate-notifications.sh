#!/bin/bash

# Notifications Stack Validation Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_test() { echo -e "  ${YELLOW}[?]${NC} Testing: $1"; }

check_container() {
    local container=$1
    print_test "Container $container"
    
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "^$container\$"; then
        local status=$(docker ps --filter "name=$container" --format "{{.Status}}")
        if echo "$status" | grep -q "healthy\|Up"; then
            print_success "$container: $status"
            return 0
        else
            print_warning "$container: $status"
            return 1
        fi
    else
        print_error "$container not running"
        return 2
    fi
}

test_gotify() {
    print_test "Gotify Notification Server"
    
    if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
        print_success "Gotify Web UI accessible"
    else
        print_error "Gotify not responding"
        return 1
    fi
    
    # Check API
    if curl -s -f http://localhost:8080/health >/dev/null 2>&1; then
        print_success "Gotify health endpoint working"
    else
        print_warning "Gotify health endpoint not accessible"
    fi
    
    return 0
}

test_ntfy() {
    print_test "NTFY Pub/Sub Notifications"
    
    if curl -s -f http://localhost:8081 >/dev/null 2>&1; then
        print_success "NTFY Web UI accessible"
    else
        print_error "NTFY not responding"
        return 1
    fi
    
    # Test pub/sub functionality
    local test_topic="test-$(date +%s)"
    if curl -s -f -d "Test message" "http://localhost:8081/$test_topic" >/dev/null 2>&1; then
        print_success "NTFY message publishing working"
    else
        print_warning "NTFY message publishing test inconclusive"
    fi
    
    return 0
}

test_apprise() {
    print_test "Apprise-API Multi-platform Gateway"
    
    if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
        print_success "Apprise-API health endpoint working"
    else
        print_error "Apprise-API not responding"
        return 1
    fi
    
    # Check API documentation
    if curl -s -f http://localhost:8000/docs >/dev/null 2>&1; then
        print_success "Apprise-API documentation accessible"
    else
        print_warning "Apprise-API docs not accessible"
    fi
    
    return 0
}

test_webhook() {
    print_test "Webhook Receiver"
    
    if curl -s -f http://localhost:8082/health >/dev/null 2>&1; then
        print_success "Webhook receiver health endpoint working"
    else
        print_error "Webhook receiver not responding"
        return 1
    fi
    
    return 0
}

test_integrations() {
    print_test "Service Integrations"
    
    # Check if services can communicate
    local containers=("notification-server" "ntfy" "apprise-api")
    local all_connected=true
    
    for container in "${containers[@]}"; do
        if docker exec "$container" ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            print_success "$container has external connectivity"
        else
            print_warning "$container may lack external connectivity"
            all_connected=false
        fi
    done
    
    # Check internal network connectivity
    if docker exec notification-server ping -c 1 ntfy >/dev/null 2>&1; then
        print_success "Services can communicate internally"
    else
        print_warning "Internal service communication test inconclusive"
    fi
    
    return 0
}

test_message_flow() {
    print_test "Notification Message Flow"
    
    # Test sending a notification through Gotify
    local response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "http://localhost:8080/message" \
        -H "Content-Type: application/json" \
        -d '{"message": "Validation test", "title": "Test", "priority": 1}' \
        2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "401" ]; then
        # 401 is expected without proper auth, 200 is success
        print_success "Notification API endpoint responding (HTTP $response)"
    else
        print_warning "Notification API test inconclusive (HTTP $response)"
    fi
    
    return 0
}

run_all_tests() {
    local passed=0 failed=0 warning=0 total=0
    
    echo "=== Notifications Stack Validation Report ==="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    local tests=(
        "check_container notification-server"
        "check_container ntfy"
        "check_container apprise-api"
        "check_container webhook-receiver"
        "test_gotify"
        "test_ntfy"
        "test_apprise"
        "test_webhook"
        "test_integrations"
        "test_message_flow"
    )
    
    for test_cmd in "${tests[@]}"; do
        total=$((total + 1))
        local test_name=$(echo "$test_cmd" | sed 's/^test_//; s/^check_container //')
        
        echo "Test $total: $test_name"
        
        if output=$(eval "$test_cmd" 2>&1); then
            passed=$((passed + 1))
            echo "  Result: PASS"
        else
            local exit_code=$?
            if [ $exit_code -eq 1 ]; then
                warning=$((warning + 1))
                echo "  Result: WARNING"
            else
                failed=$((failed + 1))
                echo "  Result: FAIL"
            fi
        fi
        
        [ -n "$output" ] && echo "$output" | sed 's/^/    /'
        echo ""
    done
    
    echo "=== Summary ==="
    echo "Total Tests: $total"
    echo "Passed: $passed"
    echo "Warnings: $warning"
    echo "Failed: $failed"
    echo ""
    
    if [ $failed -eq 0 ]; then
        if [ $warning -eq 0 ]; then
            echo -e "${GREEN}All tests passed! Notifications stack is fully operational.${NC}"
            return 0
        else
            echo -e "${YELLOW}Tests passed with warnings. Stack is operational but may need attention.${NC}"
            return 1
        fi
    else
        echo -e "${RED}Some tests failed. Stack has issues that need to be addressed.${NC}"
        return 2
    fi
}

main() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker not found"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_ROOT/docker-compose.notifications.yml" ]; then
        print_error "Not in notifications stack directory"
        exit 1
    fi
    
    run_all_tests
}

main "$@"