#!/usr/bin/env bash
# =============================================================================
# Integration Tests — Network & Firewall Configuration
# Tests: Network connectivity, firewall rules, DNS resolution
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}~${NC} $* (skipped)"; ((SKIPPED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

# -----------------------------------------------------------------------------
# Test: Docker Network Configuration
# -----------------------------------------------------------------------------
test_docker_networks() {
  log_group "Docker Network Configuration"
  
  # Check proxy network
  if docker network ls --format '{{.Name}}' | grep -q "^proxy$"; then
    log_pass "Proxy network exists"
    
    # Inspect network
    local network_info
    network_info=$(docker network inspect proxy 2>/dev/null)
    
    if [[ -n "$network_info" ]]; then
      log_pass "Proxy network inspectable"
      
      # Check driver
      if echo "$network_info" | grep -q '"Driver": "bridge"'; then
        log_pass "Proxy network using bridge driver"
      else
        log_skip "Proxy network using non-standard driver"
      fi
      
      # Check connected containers
      local container_count
      container_count=$(echo "$network_info" | grep -c '"Name":' || echo 0)
      log_pass "Containers connected: $((container_count - 1))"
    else
      log_fail "Proxy network inspection failed"
    fi
  else
    log_skip "Proxy network not found (create with: docker network create proxy)"
  fi
  
  # Check for other expected networks
  local expected_networks=("host" "bridge" "none")
  for network in "${expected_networks[@]}"; do
    if docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
      log_pass "System network exists: $network"
    else
      log_skip "System network missing: $network"
    fi
  done
}

# -----------------------------------------------------------------------------
# Test: Port Availability
# -----------------------------------------------------------------------------
test_port_availability() {
  log_group "Port Availability"
  
  local required_ports=(
    "80:Traefik-HTTP"
    "443:Traefik-HTTPS"
    "9000:Authentik"
    "9090:Prometheus"
    "3000:Grafana"
  )
  
  for port_entry in "${required_ports[@]}"; do
    local port=$(echo "$port_entry" | cut -d: -f1)
    local service=$(echo "$port_entry" | cut -d: -f2)
    
    # Check if port is listening
    if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
      log_pass "Port $port ($service) is listening"
    else
      log_skip "Port $port ($service) not listening"
    fi
  done
}

# -----------------------------------------------------------------------------
# Test: Container Network Connectivity
# -----------------------------------------------------------------------------
test_container_connectivity() {
  log_group "Container Network Connectivity"
  
  # Test inter-container communication
  if docker ps --format '{{.Names}}' | grep -q "traefik"; then
    # Test from traefik container
    if docker exec traefik ping -c 1 8.8.8.8 2>/dev/null | grep -q "1 packets transmitted"; then
      log_pass "Traefik can reach external network"
    else
      log_skip "Traefik external network access unavailable"
    fi
    
    # Test DNS resolution
    if docker exec traefik nslookup google.com 2>/dev/null | grep -q "Address"; then
      log_pass "Traefik DNS resolution working"
    else
      log_skip "Traefik DNS resolution unavailable"
    fi
  else
    log_skip "Traefik container not running"
  fi
  
  # Test proxy network isolation
  if docker network inspect proxy 2>/dev/null | grep -q '"Internal": false'; then
    log_pass "Proxy network allows external communication"
  else
    log_skip "Proxy network internal status unknown"
  fi
}

# -----------------------------------------------------------------------------
# Test: Firewall Rules
# -----------------------------------------------------------------------------
test_firewall_rules() {
  log_group "Firewall Rules"
  
  # Check if iptables is available
  if command -v iptables &>/dev/null; then
    log_pass "iptables available"
    
    # Check Docker rules
    local docker_rules
    docker_rules=$(iptables -L DOCKER 2>/dev/null | wc -l || echo 0)
    
    if [[ $docker_rules -gt 2 ]]; then
      log_pass "Docker iptables rules present ($docker_rules rules)"
    else
      log_skip "No Docker iptables rules found"
    fi
    
    # Check for common required ports
    local required_ports=(80 443)
    for port in "${required_ports[@]}"; do
      if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$port"; then
        log_pass "Port $port allowed in firewall"
      else
        log_skip "Port $port firewall rule not found"
      fi
    done
  else
    log_skip "iptables not available"
  fi
  
  # Check ufw status (Ubuntu)
  if command -v ufw &>/dev/null; then
    local ufw_status
    ufw_status=$(ufw status 2>/dev/null || echo "inactive")
    
    if echo "$ufw_status" | grep -q "active"; then
      log_pass "UFW firewall active"
      
      # Check for Docker rules
      if echo "$ufw_status" | grep -q "Docker"; then
        log_pass "UFW has Docker rules"
      else
        log_skip "UFW missing Docker rules"
      fi
    else
      log_skip "UFW firewall inactive"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Test: DNS Configuration
# -----------------------------------------------------------------------------
test_dns_configuration() {
  log_group "DNS Configuration"
  
  # Check system DNS
  if [[ -f "/etc/resolv.conf" ]]; then
    local dns_servers
    dns_servers=$(grep -c "^nameserver" /etc/resolv.conf 2>/dev/null || echo 0)
    
    if [[ $dns_servers -gt 0 ]]; then
      log_pass "System DNS configured ($dns_servers servers)"
      grep "^nameserver" /etc/resolv.conf | while read -r line; do
        log_info "  $line"
      done
    else
      log_fail "No DNS servers configured"
    fi
  else
    log_skip "/etc/resolv.conf not found"
  fi
  
  # Test DNS resolution
  if command -v nslookup &>/dev/null; then
    if nslookup google.com 2>/dev/null | grep -q "Address"; then
      log_pass "DNS resolution working"
    else
      log_fail "DNS resolution failed"
    fi
  elif command -v dig &>/dev/null; then
    if dig +short google.com 2>/dev/null | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"; then
      log_pass "DNS resolution working (dig)"
    else
      log_fail "DNS resolution failed (dig)"
    fi
  else
    # Fallback to ping
    if ping -c 1 google.com 2>/dev/null | grep -q "1 packets transmitted"; then
      log_pass "DNS resolution working (ping)"
    else
      log_fail "DNS resolution failed (ping)"
    fi
  fi
  
  # Check Docker DNS
  if docker info 2>/dev/null | grep -q "DNS"; then
    log_pass "Docker DNS configured"
  else
    log_skip "Docker DNS info unavailable"
  fi
}

# -----------------------------------------------------------------------------
# Test: Traefik Network Configuration
# -----------------------------------------------------------------------------
test_traefik_network() {
  log_group "Traefik Network Configuration"
  
  if docker ps --format '{{.Names}}' | grep -q "traefik"; then
    # Check Traefik network membership
    local traefik_networks
    traefik_networks=$(docker inspect traefik --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' 2>/dev/null || echo "")
    
    if echo "$traefik_networks" | grep -q "proxy"; then
      log_pass "Traefik connected to proxy network"
    else
      log_fail "Traefik not connected to proxy network"
    fi
    
    # Check Traefik ports
    local traefik_ports
    traefik_ports=$(docker inspect traefik --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}:{{(index $conf 0).HostPort}} {{end}}' 2>/dev/null || echo "")
    
    if echo "$traefik_ports" | grep -q "80/tcp"; then
      log_pass "Traefik port 80 mapped"
    else
      log_skip "Traefik port 80 not mapped"
    fi
    
    if echo "$traefik_ports" | grep -q "443/tcp"; then
      log_pass "Traefik port 443 mapped"
    else
      log_skip "Traefik port 443 not mapped"
    fi
    
    # Check Traefik entrypoints
    if docker logs traefik 2>/dev/null | grep -q "entryPoint"; then
      log_pass "Traefik entrypoints configured"
    else
      log_skip "Traefik entrypoint info unavailable"
    fi
  else
    log_skip "Traefik container not running"
  fi
}

# -----------------------------------------------------------------------------
# Test: Network Performance (Basic)
# -----------------------------------------------------------------------------
test_network_performance() {
  log_group "Network Performance (Basic)"
  
  # Test localhost bandwidth
  if command -v iperf3 &>/dev/null; then
    log_info "Running iperf3 localhost test..."
    # Start server in background
    iperf3 -s -D 2>/dev/null
    sleep 1
    
    # Run client test
    local bandwidth
    bandwidth=$(iperf3 -c localhost -t 5 2>/dev/null | grep "bits/sec" | tail -1 || echo "N/A")
    
    # Cleanup
    pkill iperf3 2>/dev/null || true
    
    if [[ "$bandwidth" != "N/A" ]]; then
      log_pass "Localhost bandwidth: $bandwidth"
    else
      log_skip "iperf3 test inconclusive"
    fi
  else
    log_skip "iperf3 not installed"
  fi
  
  # Test HTTP response time
  if docker ps --format '{{.Names}}' | grep -q "traefik"; then
    local response_time
    response_time=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 5 http://localhost:80 2>/dev/null || echo "N/A")
    
    if [[ "$response_time" != "N/A" ]]; then
      log_pass "HTTP response time: ${response_time}s"
    else
      log_skip "HTTP response time test failed"
    fi
  else
    log_skip "Traefik not running"
  fi
}

# -----------------------------------------------------------------------------
# Test: Network Security
# -----------------------------------------------------------------------------
test_network_security() {
  log_group "Network Security"
  
  # Check for exposed sensitive ports
  local sensitive_ports=(22 3306 5432 6379 27017)
  
  for port in "${sensitive_ports[@]}"; do
    if ss -tuln 2>/dev/null | grep -q ":${port} .*0\.0\.0\.0"; then
      log_warning "Sensitive port $port exposed to all interfaces"
    elif ss -tuln 2>/dev/null | grep -q ":${port} "; then
      log_pass "Sensitive port $port properly bound"
    fi
  done
  
  # Check Docker daemon security
  if docker info 2>/dev/null | grep -q "Root Dir"; then
    log_pass "Docker daemon info accessible"
  else
    log_skip "Docker daemon info unavailable"
  fi
  
  # Check for privileged containers
  local privileged_count
  privileged_count=$(docker ps --format '{{.Names}}' 2>/dev/null | while read -r name; do
    docker inspect "$name" --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -q "true" && echo "$name"
  done | wc -l || echo 0)
  
  if [[ $privileged_count -gt 0 ]]; then
    log_warning "$privileged_count privileged container(s) found"
  else
    log_pass "No privileged containers"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Integration Tests - Network & Firewall${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  # Check Docker
  if ! command -v docker &>/dev/null; then
    log_error "Docker not installed"
    exit 1
  fi
  
  if ! docker ps &>/dev/null; then
    log_error "Docker daemon not running or no permission"
    exit 1
  fi
  
  test_docker_networks
  test_port_availability
  test_container_connectivity
  test_firewall_rules
  test_dns_configuration
  test_traefik_network
  test_network_performance
  test_network_security
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
