#!/bin/bash

# Network Stack Setup Script
# Sets up AdGuard Home, Unbound, WireGuard, Traefik, and monitoring

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

check_prerequisites() {
    print_status "Checking prerequisites..."
    command -v docker >/dev/null 2>&1 || { print_error "Docker required"; exit 1; }
    
    if command -v docker-compose >/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose required"; exit 1
    fi
}

setup_directories() {
    print_status "Setting up directories..."
    mkdir -p "$PROJECT_ROOT"/data/{adguard/{work,conf},unbound,wireguard/{config,peer-configs},traefik/letsencrypt,netdata,smokeping/{config,data}}
    mkdir -p "$PROJECT_ROOT"/config/{adguard,unbound,traefik/{dynamic},netdata}
    mkdir -p "$PROJECT_ROOT"/logs
    chmod -R 755 "$PROJECT_ROOT"/config
}

generate_configs() {
    print_status "Generating configuration files..."
    
    # Unbound config
    cat > "$PROJECT_ROOT/config/unbound/unbound.conf" << 'EOF'
server:
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 172.21.0.0/24 allow
    access-control: 10.13.13.0/24 allow
    access-control: 127.0.0.0/8 allow
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    num-threads: 4
    msg-cache-size: 256m
    rrset-cache-size: 512m
    key-cache-size: 128m
    so-rcvbuf: 4m
    so-sndbuf: 4m
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    hide-identity: yes
    hide-version: yes
    identity: "DNS"
    version: ""

forward-zone:
    name: "."
    forward-addr: 1.1.1.1@853
    forward-addr: 8.8.8.8@853
    forward-addr: 9.9.9.9@853
    forward-tls-upstream: yes
EOF
    
    # Traefik config
    cat > "$PROJECT_ROOT/config/traefik/traefik.yml" << 'EOF'
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /letsencrypt/acme.json
      tlschallenge: {}

providers:
  docker:
    exposedByDefault: false
    network: network-stack

log:
  level: INFO
  filePath: /var/log/traefik/traefik.log
EOF
}

start_services() {
    print_status "Starting Network Stack..."
    cd "$PROJECT_ROOT"
    
    if [ -f .env.network ]; then
        export $(grep -v '^#' .env.network | xargs)
    fi
    
    $DOCKER_COMPOSE_CMD -f docker-compose.network.yml up -d
    
    print_status "Waiting for services to start..."
    sleep 15
}

check_health() {
    print_status "Checking service health..."
    
    local services=("adguard-home" "unbound" "wireguard" "traefik")
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Status}}" | grep -q "Up"; then
            print_status "$service: Running"
        else
            print_warning "$service: Not running"
        fi
    done
}

display_info() {
    local ip=$(hostname -I | awk '{print $1}')
    
    cat << EOF

=== Network Stack Installation Complete ===

Services:
- AdGuard Home: http://$ip:3000 (DNS filtering)
- Unbound: $ip:53 (Recursive DNS)
- WireGuard: $ip:51820 (VPN)
- Traefik Dashboard: http://$ip:8080
- Netdata: http://$ip:19999 (Monitoring)
- SmokePing: http://$ip:8081 (Latency)

Configuration:
- DNS Server: $ip
- WireGuard configs: $PROJECT_ROOT/data/wireguard/peer-configs/
- Traefik config: $PROJECT_ROOT/config/traefik/

Next Steps:
1. Change default passwords in .env.network
2. Configure WireGuard clients
3. Set up Traefik domains and SSL
4. Configure AdGuard filtering rules
5. Set up monitoring alerts

To stop: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.network.yml down
To view logs: cd $PROJECT_ROOT && $DOCKER_COMPOSE_CMD -f docker-compose.network.yml logs -f
EOF
}

main() {
    print_status "Starting Network Stack Setup"
    echo ""
    
    check_prerequisites
    setup_directories
    generate_configs
    start_services
    check_health
    display_info
    
    print_status "Setup complete!"
}

main "$@"