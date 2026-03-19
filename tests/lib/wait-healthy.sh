#!/bin/bash
# wait-healthy.sh - Wait for containers to be healthy
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

show_help() {
    cat << EOF
Wait for containers to be healthy

Usage: $0 [Options]

Options:
  --timeout <seconds>   Maximum wait time (default: 120)
  --stack <name>        Wait for specific stack containers
  --all                 Wait for all known containers
  --help                Show this help

Examples:
  $0 --timeout 120
  $0 --stack base
  $0 --all

EOF
}

# 等待单个容器健康
wait_container() {
    local container="$1"
    local timeout="$2"
    local elapsed=0
    
    echo -n "  Waiting for $container..."
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        
        if [[ "$status" != "running" ]]; then
            sleep 2
            ((elapsed+=2))
            continue
        fi
        
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        
        if [[ "$health" == "healthy" ]]; then
            echo -e " ${GREEN}✅ healthy${NC}"
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            echo -e " ${RED}❌ unhealthy${NC}"
            return 1
        elif [[ -z "$health" ]]; then
            # 没有 healthcheck，只要 running 就认为 OK
            echo -e " ${GREEN}✅ running (no healthcheck)${NC}"
            return 0
        fi
        
        sleep 2
        ((elapsed+=2))
        echo -n "."
    done
    
    echo -e " ${RED}❌ timeout${NC}"
    return 1
}

# Base stack 容器
wait_base_stack() {
    local timeout="$1"
    echo -e "${YELLOW}Waiting for base stack containers...${NC}"
    
    local containers=("traefik" "portainer" "watchtower")
    local failed=0
    
    for container in "${containers[@]}"; do
        if ! wait_container "$container" "$timeout"; then
            ((failed++))
        fi
    done
    
    return $failed
}

# Media stack 容器
wait_media_stack() {
    local timeout="$1"
    echo -e "${YELLOW}Waiting for media stack containers...${NC}"
    
    local containers=("jellyfin" "sonarr" "radarr" "qbittorrent")
    local failed=0
    
    for container in "${containers[@]}"; do
        wait_container "$container" "$timeout" || ((failed++))
    done
    
    return $failed
}

# Monitoring stack 容器
wait_monitoring_stack() {
    local timeout="$1"
    echo -e "${YELLOW}Waiting for monitoring stack containers...${NC}"
    
    local containers=("grafana" "prometheus" "alertmanager" "cadvisor" "nodeexporter")
    local failed=0
    
    for container in "${containers[@]}"; do
        wait_container "$container" "$timeout" || ((failed++))
    done
    
    return $failed
}

wait_all_containers() {
    local timeout="$1"
    echo -e "${YELLOW}Waiting for all containers...${NC}"
    
    local containers=(
        "traefik" "portainer" "watchtower"
        "jellyfin" "sonarr" "radarr" "qbittorrent"
        "grafana" "prometheus" "alertmanager" "cadvisor" "nodeexporter"
        "nextcloud" "samba" "syncthing"
        "adguard" "pihole"
        "gitea" "n8n"
        "ollama" "openwebui"
        "authentik-server" "authentik-worker"
        "postgres" "mysql" "mongodb" "redis"
    )
    
    local failed=0
    
    for container in "${containers[@]}"; do
        # 只等待存在的容器
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            wait_container "$container" "$timeout" || ((failed++))
        else
            echo "  Skipping $container (not found)"
        fi
    done
    
    return $failed
}

main() {
    local timeout=120
    local stack=""
    local wait_all=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            --stack) stack="$2"; shift 2 ;;
            --all) wait_all=true; shift ;;
            --help) show_help; exit 0 ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
    
    if [[ "$wait_all" == true ]]; then
        wait_all_containers "$timeout"
    elif [[ -n "$stack" ]]; then
        case "$stack" in
            base) wait_base_stack "$timeout" ;;
            media) wait_media_stack "$timeout" ;;
            monitoring) wait_monitoring_stack "$timeout" ;;
            *) echo "Unknown stack: $stack"; exit 1 ;;
        esac
    else
        echo "Usage: $0 --stack <name> | --all | --help"
        exit 1
    fi
}

main "$@"
