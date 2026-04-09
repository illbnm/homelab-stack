#!/bin/bash

# Storage Stack Validation Script
# Validates the health and functionality of the storage stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_test() {
    echo -e "  ${YELLOW}[?]${NC} Testing: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker container health
check_container() {
    local container_name=$1
    print_test "Container $container_name"
    
    if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name\$"; then
        local status=$(docker ps --filter "name=$container_name" --format "{{.Status}}")
        if echo "$status" | grep -q "healthy"; then
            print_success "$container_name is running and healthy"
            return 0
        elif echo "$status" | grep -q "Up"; then
            print_warning "$container_name is running but health check may have failed"
            return 1
        else
            print_error "$container_name is not running properly"
            return 2
        fi
    else
        print_error "$container_name is not running"
        return 3
    fi
}

# Function to test NFS functionality
test_nfs() {
    print_test "NFS Server functionality"
    
    # Check if NFS ports are listening
    if netstat -tuln | grep ':2049 ' > /dev/null; then
        print_success "NFS port 2049 is listening"
    else
        print_error "NFS port 2049 is not listening"
        return 1
    fi
    
    # Test basic NFS functionality (if rpcbind is available)
    if command_exists rpcinfo; then
        if rpcinfo -p localhost | grep -q "nfs"; then
            print_success "NFS service registered with portmapper"
        else
            print_warning "NFS service not found in portmapper (may be normal for containerized NFS)"
        fi
    fi
    
    return 0
}

# Function to test Syncthing functionality
test_syncthing() {
    print_test "Syncthing Web UI"
    
    # Check if Syncthing web UI is accessible
    if curl -s -f http://localhost:8384 > /dev/null 2>&1; then
        print_success "Syncthing Web UI is accessible"
    else
        print_error "Cannot access Syncthing Web UI"
        return 1
    fi
    
    # Check API endpoint
    local api_key=$(grep -oP '(?<=<apikey>).*?(?=</apikey>)' "$PROJECT_ROOT/config/syncthing/config.xml" 2>/dev/null || echo "")
    if [ -n "$api_key" ] && [ "$api_key" != "change_me" ]; then
        if curl -s -f -H "X-API-Key: $api_key" http://localhost:8384/rest/system/status > /dev/null 2>&1; then
            print_success "Syncthing API is accessible"
        else
            print_warning "Syncthing API may not be properly configured"
        fi
    else
        print_warning "Syncthing API key not configured or is default"
    fi
    
    return 0
}

# Function to test MinIO functionality
test_minio() {
    print_test "MinIO Object Storage"
    
    # Check MinIO API
    if curl -s -f http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        print_success "MinIO API is healthy"
    else
        print_error "MinIO API is not responding"
        return 1
    fi
    
    # Check MinIO Console
    if curl -s -f http://localhost:9001 > /dev/null 2>&1; then
        print_success "MinIO Console is accessible"
    else
        print_error "MinIO Console is not accessible"
        return 2
    fi
    
    # Test bucket creation (if credentials are available)
    local access_key="${MINIO_ROOT_USER:-admin}"
    local secret_key="${MINIO_ROOT_PASSWORD:-changeme123}"
    
    if [ "$access_key" != "admin" ] || [ "$secret_key" != "changeme123" ]; then
        # Use mc command if available
        if command_exists mc; then
            if mc alias set test-minio http://localhost:9000 "$access_key" "$secret_key" > /dev/null 2>&1; then
                if mc ls test-minio > /dev/null 2>&1; then
                    print_success "MinIO authentication and bucket access working"
                else
                    print_warning "MinIO authentication works but bucket access failed"
                fi
                mc alias remove test-minio > /dev/null 2>&1
            else
                print_warning "MinIO authentication test skipped (mc command issue)"
            fi
        fi
    else
        print_warning "MinIO using default credentials - please change in production"
    fi
    
    return 0
}

# Function to test monitoring endpoints
test_monitoring() {
    print_test "Monitoring Services"
    
    # Test Node Exporter
    if curl -s -f http://localhost:9100/metrics > /dev/null 2>&1; then
        print_success "Node Exporter metrics endpoint is accessible"
    else
        print_error "Node Exporter is not responding"
        return 1
    fi
    
    # Test cAdvisor
    if curl -s -f http://localhost:8080/metrics > /dev/null 2>&1; then
        print_success "cAdvisor metrics endpoint is accessible"
    else
        print_error "cAdvisor is not responding"
        return 2
    fi
    
    return 0
}

# Function to test network connectivity
test_network() {
    print_test "Internal Network Connectivity"
    
    # Test connectivity between containers
    local containers=("nfs-server" "syncthing" "minio")
    local all_connected=true
    
    for container in "${containers[@]}"; do
        if docker exec "$container" ping -c 1 8.8.8.8 > /dev/null 2>&1; then
            print_success "$container has external network connectivity"
        else
            print_warning "$container may not have external network connectivity"
            all_connected=false
        fi
    done
    
    if $all_connected; then
        print_success "All containers have network connectivity"
    else
        print_warning "Some containers may have network issues"
    fi
    
    return 0
}

# Function to test disk space
test_disk_space() {
    print_test "Disk Space Availability"
    
    local threshold=10 # 10% minimum free space
    local free_percent=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    local available=$((100 - free_percent))
    
    if [ $available -ge $threshold ]; then
        print_success "Adequate disk space available ($available% free)"
    else
        print_error "Low disk space ($available% free, minimum $threshold% required)"
        return 1
    fi
    
    return 0
}

# Function to test resource usage
test_resources() {
    print_test "System Resource Usage"
    
    # Check memory usage
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local used_mem=$(free -m | awk '/^Mem:/{print $3}')
    local mem_percent=$((used_mem * 100 / total_mem))
    
    if [ $mem_percent -lt 80 ]; then
        print_success "Memory usage is acceptable ($mem_percent% used)"
    else
        print_warning "High memory usage ($mem_percent% used)"
    fi
    
    # Check CPU load
    local load=$(awk '{print $1}' /proc/loadavg)
    local cores=$(nproc)
    local load_percent=$(echo "scale=0; $load * 100 / $cores" | bc)
    
    if [ $(echo "$load_percent < 70" | bc) -eq 1 ]; then
        print_success "CPU load is acceptable ($load%, $load_percent% of $cores cores)"
    else
        print_warning "High CPU load ($load%, $load_percent% of $cores cores)"
    fi
    
    return 0
}

# Function to run all tests
run_all_tests() {
    local tests_passed=0
    local tests_failed=0
    local tests_warning=0
    local total_tests=0
    
    echo "=== Storage Stack Validation Report ==="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    # Define test functions
    local test_functions=(
        "check_container nfs-server"
        "check_container syncthing"
        "check_container minio"
        "test_nfs"
        "test_syncthing"
        "test_minio"
        "test_monitoring"
        "test_network"
        "test_disk_space"
        "test_resources"
    )
    
    # Run each test
    for test_cmd in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        
        # Extract test name
        local test_name=$(echo "$test_cmd" | sed 's/^test_//; s/^check_container //')
        
        echo "Test $total_tests: $test_name"
        
        # Run the test and capture output/exit code
        local output
        local exit_code
        
        # Use eval to run the test command
        if output=$(eval "$test_cmd" 2>&1); then
            tests_passed=$((tests_passed + 1))
            echo "  Result: PASS"
        else
            exit_code=$?
            if [ $exit_code -eq 1 ]; then
                tests_warning=$((tests_warning + 1))
                echo "  Result: WARNING"
            else
                tests_failed=$((tests_failed + 1))
                echo "  Result: FAIL"
            fi
        fi
        
        # Print any output from the test
        if [ -n "$output" ]; then
            echo "$output" | sed 's/^/    /'
        fi
        
        echo ""
    done
    
    # Print summary
    echo "=== Summary ==="
    echo "Total Tests: $total_tests"
    echo "Passed: $tests_passed"
    echo "Warnings: $tests_warning"
    echo "Failed: $tests_failed"
    echo ""
    
    # Overall status
    if [ $tests_failed -eq 0 ]; then
        if [ $tests_warning -eq 0 ]; then
            echo -e "${GREEN}All tests passed! Storage stack is fully operational.${NC}"
            return 0
        else
            echo -e "${YELLOW}Tests passed with warnings. Storage stack is operational but may need attention.${NC}"
            return 1
        fi
    else
        echo -e "${RED}Some tests failed. Storage stack may have issues that need to be addressed.${NC}"
        return 2
    fi
}

# Main execution
main() {
    # Check if Docker is available
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "$PROJECT_ROOT/docker-compose.storage.yml" ]; then
        print_error "Could not find docker-compose.storage.yml in $PROJECT_ROOT"
        print_error "Please run this script from the storage stack directory"
        exit 1
    fi
    
    # Run all tests
    run_all_tests
}

# Run main function
main "$@"