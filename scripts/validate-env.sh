#!/usr/bin/env bash
# =============================================================================
# Environment Validation Script
# =============================================================================
# Validates environment configuration for homelab-stack deployment
# Checks: Docker, dependencies, environment variables, network, resources
#
# Usage:
#   ./validate-env.sh              # Full validation
#   ./validate-env.sh --quick      # Quick check (skip network tests)
#   ./validate-env.sh --fix        # Attempt to fix issues
#   ./validate-env.sh --json       # JSON output
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_pass()  { echo -e "${GREEN}✓${NC} $*"; }
log_fail()  { echo -e "${RED}✗${NC} $*"; }

# Validation results
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a ERRORS
declare -a WARNINGS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

# =============================================================================
# Help
# =============================================================================
show_help() {
    cat << EOF
Environment Validation Script

Validates environment configuration for homelab-stack deployment.

Usage:
  $0 [OPTIONS]

Options:
  --quick     Quick check (skip network tests)
  --fix       Attempt to automatically fix issues
  --json      Output results in JSON format
  --report    Generate detailed validation report
  -h, --help  Show this help message

Checks performed:
  - Docker version and configuration
  - Required tools and dependencies
  - Environment variables (.env file)
  - Network connectivity
  - System resources (CPU, memory, disk)
  - File permissions
  - Docker Compose configuration

Exit codes:
  0 = All checks passed
  1 = Critical issues found
  2 = Warnings found (non-critical)

Examples:
  # Full validation
  $0

  # Quick check
  $0 --quick

  # Generate report
  $0 --report > validation-report.txt

EOF
}

# =============================================================================
# Validation Functions
# =============================================================================

# Check Docker
check_docker() {
    echo -e "\n${BOLD}Docker Checks${NC}"
    echo "----------------------------------------"
    
    # Docker version
    if command -v docker &>/dev/null; then
        local version
        version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        local major minor
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        
        if [[ $major -ge 24 ]] || ([[ $major -eq 24 ]] && [[ $minor -ge 0 ]]); then
            log_pass "Docker version: $version (>= 24.0)"
            ((PASS_COUNT++))
        else
            log_fail "Docker version: $version (requires >= 24.0)"
            ERRORS+=("Docker version too old: $version")
            ((FAIL_COUNT++))
        fi
    else
        log_fail "Docker not installed"
        ERRORS+=("Docker not installed")
        ((FAIL_COUNT++))
        return 1
    fi
    
    # Docker running
    if systemctl is-active --quiet docker; then
        log_pass "Docker service: running"
        ((PASS_COUNT++))
    else
        log_fail "Docker service: not running"
        ERRORS+=("Docker service not running")
        ((FAIL_COUNT++))
    fi
    
    # Docker Compose
    if docker compose version &>/dev/null; then
        log_pass "Docker Compose: $(docker compose version --short)"
        ((PASS_COUNT++))
    elif command -v docker-compose &>/dev/null; then
        log_warn "docker-compose (v1) found, v2 recommended"
        WARNINGS+=("Using docker-compose v1, upgrade to v2 recommended")
        ((WARN_COUNT++))
    else
        log_fail "Docker Compose not found"
        ERRORS+=("Docker Compose not installed")
        ((FAIL_COUNT++))
    fi
    
    # Docker configuration
    if [[ -f "/etc/docker/daemon.json" ]]; then
        if jq empty /etc/docker/daemon.json 2>/dev/null; then
            log_pass "Docker daemon.json: valid JSON"
            ((PASS_COUNT++))
        else
            log_fail "Docker daemon.json: invalid JSON"
            ERRORS+=("Invalid /etc/docker/daemon.json")
            ((FAIL_COUNT++))
        fi
    fi
}

# Check required tools
check_dependencies() {
    echo -e "\n${BOLD}Dependency Checks${NC}"
    echo "----------------------------------------"
    
    local required_tools=("curl" "wget" "git" "openssl" "jq" "bc")
    local optional_tools=("htop" "iotop" "ncdu" "tree")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_pass "$tool: installed"
            ((PASS_COUNT++))
        else
            log_fail "$tool: missing"
            ERRORS+=("Missing required tool: $tool")
            ((FAIL_COUNT++))
        fi
    done
    
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_pass "$tool: installed (optional)"
            ((PASS_COUNT++))
        else
            log_warn "$tool: missing (optional)"
            ((WARN_COUNT++))
        fi
    done
}

# Check environment variables
check_env_file() {
    echo -e "\n${BOLD}Environment File Checks${NC}"
    echo "----------------------------------------"
    
    # Check .env exists
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f "$ENV_EXAMPLE" ]]; then
            log_warn ".env file missing, .env.example found"
            WARNINGS+=("No .env file, copy from .env.example")
            ((WARN_COUNT++))
        else
            log_fail ".env file missing"
            ERRORS+=("No .env file found")
            ((FAIL_COUNT++))
            return 1
        fi
    else
        log_pass ".env file: exists"
        ((PASS_COUNT++))
    fi
    
    # Load environment variables
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE" 2>/dev/null || true
        set +a
        
        # Check required variables
        local required_vars=(
            "DOMAIN"
            "TRAEFIK_ACME_EMAIL"
            "AUTHENTIK_SECRET_KEY"
        )
        
        local recommended_vars=(
            "TZ"
            "PUID"
            "PGID"
            "DOCKER_LOGS_DIR"
        )
        
        for var in "${required_vars[@]}"; do
            if [[ -n "${!var:-}" ]]; then
                log_pass "$var: set"
                ((PASS_COUNT++))
            else
                log_fail "$var: missing (required)"
                ERRORS+=("Missing required env var: $var")
                ((FAIL_COUNT++))
            fi
        done
        
        for var in "${recommended_vars[@]}"; do
            if [[ -n "${!var:-}" ]]; then
                log_pass "$var: set"
                ((PASS_COUNT++))
            else
                log_warn "$var: missing (recommended)"
                WARNINGS+=("Missing recommended env var: $var")
                ((WARN_COUNT++))
            fi
        done
        
        # Validate DOMAIN format
        if [[ -n "${DOMAIN:-}" ]]; then
            if [[ "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$ ]]; then
                log_pass "DOMAIN format: valid"
                ((PASS_COUNT++))
            else
                log_fail "DOMAIN format: invalid ($DOMAIN)"
                ERRORS+=("Invalid DOMAIN format: $DOMAIN")
                ((FAIL_COUNT++))
            fi
        fi
        
        # Validate email format
        if [[ -n "${TRAEFIK_ACME_EMAIL:-}" ]]; then
            if [[ "$TRAEFIK_ACME_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                log_pass "Email format: valid"
                ((PASS_COUNT++))
            else
                log_fail "Email format: invalid"
                ERRORS+=("Invalid email format: $TRAEFIK_ACME_EMAIL")
                ((FAIL_COUNT++))
            fi
        fi
    fi
}

# Check system resources
check_resources() {
    echo -e "\n${BOLD}Resource Checks${NC}"
    echo "----------------------------------------"
    
    # CPU
    local cpu_cores
    cpu_cores=$(nproc)
    if (( cpu_cores >= 2 )); then
        log_pass "CPU cores: $cpu_cores (>= 2)"
        ((PASS_COUNT++))
    else
        log_warn "CPU cores: $cpu_cores (< 2, may be insufficient)"
        WARNINGS+=("Low CPU cores: $cpu_cores")
        ((WARN_COUNT++))
    fi
    
    # Memory
    local total_mem
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if (( total_mem >= 4 )); then
        log_pass "Memory: ${total_mem}GB (>= 4GB)"
        ((PASS_COUNT++))
    elif (( total_mem >= 2 )); then
        log_warn "Memory: ${total_mem}GB (2-4GB, may be insufficient)"
        WARNINGS+=("Low memory: ${total_mem}GB")
        ((WARN_COUNT++))
    else
        log_fail "Memory: ${total_mem}GB (< 2GB, insufficient)"
        ERRORS+=("Insufficient memory: ${total_mem}GB")
        ((FAIL_COUNT++))
    fi
    
    # Disk space
    local disk_avail
    disk_avail=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( disk_avail >= 50 )); then
        log_pass "Available disk: ${disk_avail}GB (>= 50GB)"
        ((PASS_COUNT++))
    elif (( disk_avail >= 20 )); then
        log_warn "Available disk: ${disk_avail}GB (20-50GB, may be insufficient)"
        WARNINGS+=("Low disk space: ${disk_avail}GB")
        ((WARN_COUNT++))
    else
        log_fail "Available disk: ${disk_avail}GB (< 20GB, insufficient)"
        ERRORS+=("Insufficient disk space: ${disk_avail}GB")
        ((FAIL_COUNT++))
    fi
}

# Check network connectivity
check_network() {
    echo -e "\n${BOLD}Network Checks${NC}"
    echo "----------------------------------------"
    
    local endpoints=(
        "https://registry-1.docker.io"
        "https://ghcr.io"
        "https://gcr.io"
        "https://github.com"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f -s --connect-timeout 5 --max-time 10 "$endpoint" > /dev/null 2>&1; then
            log_pass "$endpoint: accessible"
            ((PASS_COUNT++))
        else
            log_warn "$endpoint: not accessible (may be network/firewall issue)"
            WARNINGS+=("Cannot reach: $endpoint")
            ((WARN_COUNT++))
        fi
    done
    
    # DNS resolution
    if host google.com &>/dev/null; then
        log_pass "DNS resolution: working"
        ((PASS_COUNT++))
    else
        log_fail "DNS resolution: failed"
        ERRORS+=("DNS resolution failed")
        ((FAIL_COUNT++))
    fi
    
    # Port availability
    local ports=(80 443)
    for port in "${ports[@]}"; do
        if ! ss -tuln | grep -q ":$port "; then
            log_pass "Port $port: available"
            ((PASS_COUNT++))
        else
            log_warn "Port $port: in use (ensure it's Traefik)"
            WARNINGS+=("Port $port already in use")
            ((WARN_COUNT++))
        fi
    done
}

# Check file permissions
check_permissions() {
    echo -e "\n${BOLD}Permission Checks${NC}"
    echo "----------------------------------------"
    
    # Check if running as root (not recommended)
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root (not recommended)"
        WARNINGS+=("Running as root user")
        ((WARN_COUNT++))
    else
        log_pass "Running as non-root user: $(whoami)"
        ((PASS_COUNT++))
    fi
    
    # Check Docker group membership
    if groups | grep -q docker; then
        log_pass "User in docker group"
        ((PASS_COUNT++))
    else
        log_warn "User not in docker group"
        WARNINGS+=("User not in docker group")
        ((WARN_COUNT++))
    fi
    
    # Check write permissions
    local check_dirs=(
        "$PROJECT_ROOT"
        "$PROJECT_ROOT/config"
        "$PROJECT_ROOT/stacks"
    )
    
    for dir in "${check_dirs[@]}"; do
        if [[ -w "$dir" ]]; then
            log_pass "Write access: $dir"
            ((PASS_COUNT++))
        else
            log_fail "No write access: $dir"
            ERRORS+=("No write permission: $dir")
            ((FAIL_COUNT++))
        fi
    done
}

# =============================================================================
# Fix Functions
# =============================================================================
attempt_fixes() {
    log_info "Attempting to fix issues..."
    
    # Create .env from example
    if [[ ! -f "$ENV_FILE" ]] && [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        log_info "Created .env from .env.example"
    fi
    
    # Install missing tools
    local missing_tools=()
    for tool in curl wget git openssl jq bc; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Attempting to install missing tools: ${missing_tools[*]}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y "${missing_tools[@]}"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing_tools[@]}"
        else
            log_warn "Cannot auto-install tools on this system"
        fi
    fi
    
    # Add user to docker group
    if ! groups | grep -q docker; then
        log_info "Adding user to docker group..."
        sudo usermod -aG docker "$(whoami)"
        log_warn "You need to logout/login for group changes to take effect"
    fi
}

# =============================================================================
# Report Generation
# =============================================================================
generate_json_report() {
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "passed": $PASS_COUNT,
    "failed": $FAIL_COUNT,
    "warnings": $WARN_COUNT,
    "status": $((FAIL_COUNT > 0 ? 1 : (WARN_COUNT > 0 ? 2 : 0)))
  },
  "errors": $(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .),
  "warnings": $(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
}
EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    local quick=false
    local fix=false
    local json_output=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick=true
                shift
                ;;
            --fix)
                fix=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Run validations
    echo -e "${BOLD}${BLUE}Homelab Stack Environment Validation${NC}"
    echo -e "${BOLD}========================================${NC}"
    
    check_docker
    check_dependencies
    check_env_file
    check_resources
    check_permissions
    
    if [[ "$quick" == "false" ]]; then
        check_network
    fi
    
    # Attempt fixes if requested
    if [[ "$fix" == "true" ]] && [[ $FAIL_COUNT -gt 0 || $WARN_COUNT -gt 0 ]]; then
        attempt_fixes
    fi
    
    # Summary
    echo -e "\n${BOLD}Summary${NC}"
    echo "========================================"
    echo -e "Passed:   ${GREEN}$PASS_COUNT${NC}"
    echo -e "Failed:   ${RED}$FAIL_COUNT${NC}"
    echo -e "Warnings: ${YELLOW}$WARN_COUNT${NC}"
    
    if [[ "$json_output" == "true" ]]; then
        generate_json_report
    else
        # Show errors
        if [[ ${#ERRORS[@]} -gt 0 ]]; then
            echo -e "\n${BOLD}${RED}Errors:${NC}"
            for error in "${ERRORS[@]}"; do
                echo "  - $error"
            done
        fi
        
        # Show warnings
        if [[ ${#WARNINGS[@]} -gt 0 ]]; then
            echo -e "\n${BOLD}${YELLOW}Warnings:${NC}"
            for warning in "${WARNINGS[@]}"; do
                echo "  - $warning"
            done
        fi
    fi
    
    # Exit with appropriate code
    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    elif [[ $WARN_COUNT -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

main "$@"
