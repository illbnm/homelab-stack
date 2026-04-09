#!/bin/bash

# Home Automation Stack Validation Script

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

test_homeassistant() {
    print_test "Home Assistant"
    
    if curl -s -f http://localhost:8123 >/dev/null 2>&1; then
        print_success "Home Assistant Web UI accessible"
    else
        print_error "Home Assistant not responding"
        return 1
    fi
    
    # Check API
    if curl -s -f http://localhost:8123/api/ >/dev/null 2>&1; then
        print_success "Home Assistant API accessible"
    else
        print_warning "Home Assistant API may not be ready"
    fi
    
    return 0
}

test_mqtt() {
    print_test "MQTT Broker"
    
    # Check if MQTT port is listening
    if netstat -tuln | grep ':1883 ' >/dev/null; then
        print_success "MQTT port 1883 listening"
    else
        print_error "MQTT port not listening"
        return 1
    fi
    
    # Test MQTT connection (if mosquitto clients are available)
    if command -v mosquitto_sub >/dev/null 2>&1; then
        if timeout 5 mosquitto_sub -h localhost -t "\$SYS/broker/uptime" -C 1 >/dev/null 2>&1; then
            print_success "MQTT broker responding"
        else
            print_warning "MQTT broker test inconclusive (install mosquitto-clients)"
        fi
    fi
    
    return 0
}

test_zigbee2mqtt() {
    print_test "Zigbee2MQTT"
    
    if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
        print_success "Zigbee2MQTT Web UI accessible"
    else
        print_warning "Zigbee2MQTT UI not accessible (may be normal if no adapter)"
        return 1
    fi
    
    # Check if Zigbee2MQTT is connected to MQTT
    if docker logs zigbee2mqtt --tail 10 2>/dev/null | grep -q "Connected to MQTT server"; then
        print_success "Zigbee2MQTT connected to MQTT"
    else
        print_warning "Zigbee2MQTT MQTT connection status unknown"
    fi
    
    return 0
}

test_nodered() {
    print_test "Node-RED"
    
    if curl -s -f http://localhost:1880 >/dev/null 2>&1; then
        print_success "Node-RED Web UI accessible"
    else
        print_error "Node-RED not responding"
        return 1
    fi
    
    return 0
}

test_integrations() {
    print_test "Service Integrations"
    
    # Check if Home Assistant can talk to MQTT
    if docker logs homeassistant --tail 20 2>/dev/null | grep -q "Connected to MQTT"; then
        print_success "Home Assistant connected to MQTT"
    else
        print_warning "Home Assistant MQTT connection status unknown"
    fi
    
    # Check if services are on same network
    local containers=("homeassistant" "zigbee2mqtt" "mosquitto")
    local all_connected=true
    
    for container in "${containers[@]}"; do
        if docker exec "$container" ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            print_success "$container has external connectivity"
        else
            print_warning "$container may lack external connectivity"
            all_connected=false
        fi
    done
    
    if $all_connected; then
        print_success "All containers have network connectivity"
    fi
    
    return 0
}

run_all_tests() {
    local passed=0 failed=0 warning=0 total=0
    
    echo "=== Home Automation Stack Validation Report ==="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    local tests=(
        "check_container homeassistant"
        "check_container zigbee2mqtt"
        "check_container mosquitto"
        "check_container nodered"
        "test_homeassistant"
        "test_mqtt"
        "test_zigbee2mqtt"
        "test_nodered"
        "test_integrations"
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
            echo -e "${GREEN}All tests passed! Home automation stack is fully operational.${NC}"
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
    
    if [ ! -f "$PROJECT_ROOT/docker-compose.home-automation.yml" ]; then
        print_error "Not in home automation stack directory"
        exit 1
    fi
    
    run_all_tests
}

main "$@"