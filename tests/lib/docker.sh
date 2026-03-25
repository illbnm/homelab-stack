#!/bin/bash
# =============================================================================
# docker.sh - Docker utility functions for testing
# =============================================================================

set -euo pipefail

# Get container status
get_container_status() {
    local name="$1"
    docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found"
}

# Get container health
get_container_health() {
    local name="$1"
    docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no_healthcheck"
}

# Check if container is running
is_container_running() {
    local name="$1"
    [[ $(get_container_status "$name") == "running" ]]
}

# Check if container is healthy
is_container_healthy() {
    local name="$1"
    [[ $(get_container_health "$name") == "healthy" ]]
}

# Wait for container to be healthy
wait_for_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            echo "Timeout waiting for $name to be healthy"
            return 1
        fi
        
        if is_container_healthy "$name"; then
            return 0
        fi
        
        sleep 2
    done
}

# Wait for all containers in compose to be healthy
wait_for_compose_healthy() {
    local compose_file="$1"
    local timeout="${2:-120}"
    
    local services
    services=$(docker compose -f "$compose_file" config --services 2>/dev/null)
    
    for service in $services; do
        wait_for_healthy "$service" "$timeout" || return 1
    done
}

# Get container IP
get_container_ip() {
    local name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null
}

# Get container logs
get_container_logs() {
    local name="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$name" 2>&1
}

# List all running containers
list_running_containers() {
    docker ps --format '{{.Names}}'
}

# Count running containers
count_running_containers() {
    docker ps -q | wc -l
}

# Check if network exists
network_exists() {
    local name="$1"
    docker network inspect "$name" &>/dev/null
}

# Check if volume exists
volume_exists() {
    local name="$1"
    docker volume inspect "$name" &>/dev/null
}
