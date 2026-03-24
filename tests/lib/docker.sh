#!/usr/bin/env bash
# ==============================================================================
# HomeLab Stack — Docker Utility Functions
# Helper functions for Docker operations in tests
# ==============================================================================

# Wait for container to be healthy
wait_for_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not-found")
        
        case "$status" in
            healthy) return 0 ;;
            unhealthy) return 1 ;;
        esac
        
        sleep "$interval"
        ((elapsed += interval))
    done
    
    return 1
}

# Wait for all containers in a compose project to be healthy
wait_for_compose_healthy() {
    local compose_file="$1"
    local project_name="${2:-homelab}"
    local timeout="${3:-300}"
    local elapsed=0
    
    local containers=$(docker compose -f "$compose_file" ps -q 2>/dev/null || true)
    
    if [[ -z "$containers" ]]; then
        return 1
    fi
    
    while [[ $elapsed -lt $timeout ]]; do
        local all_healthy=true
        
        while read -r cid; do
            local status=$(docker inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unhealthy")
            if [[ "$status" != "healthy" ]]; then
                all_healthy=false
                break
            fi
        done <<< "$containers"
        
        if [[ "$all_healthy" == true ]]; then
            return 0
        fi
        
        sleep 5
        ((elapsed += 5))
    done
    
    # Print logs for unhealthy containers on timeout
    echo "Timeout waiting for healthy containers. Container logs:"
    while read -r cid; do
        local name=$(docker inspect --format '{{.Name}}' "$cid" | sed 's/^///')
        local status=$(docker inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unknown")
        if [[ "$status" != "healthy" ]]; then
            echo "--- $name ($status) ---"
            docker logs --tail 20 "$cid" 2>&1
        fi
    done <<< "$containers"
    
    return 1
}

# Get container IP address
get_container_ip() {
    local container="$1"
    local network="${2:-proxy}"
    
    docker inspect --format \
        "{{(index .NetworkSettings.Networks \"$network\").IPAddress}}" \
        "$container" 2>/dev/null || echo ""
}

# Get container port mapping
get_container_port() {
    local container="$1"
    local internal_port="$2"
    
    docker port "$container" "$internal_port" 2>/dev/null | cut -d: -f2 || echo ""
}

# Check if container is running
is_container_running() {
    local container="$1"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"
}

# Check if container exists
is_container_exists() {
    local container="$1"
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"
}

# Get container logs
get_container_logs() {
    local container="$1"
    local lines="${2:-50}"
    docker logs --tail "$lines" "$container" 2>&1
}

# Execute command in container
exec_in_container() {
    local container="$1"
    shift
    docker exec "$container" "$@" 2>&1
}

# Restart container
restart_container() {
    local container="$1"
    docker restart "$container" >/dev/null 2>&1
}

# Stop container
stop_container() {
    local container="$1"
    docker stop "$container" >/dev/null 2>&1
}

# Start container
start_container() {
    local container="$1"
    docker start "$container" >/dev/null 2>&1
}

# Remove container
remove_container() {
    local container="$1"
    docker rm -f "$container" >/dev/null 2>&1
}

# Get Docker network ID
get_network_id() {
    local network="$1"
    docker network inspect "$network" --format '{{.Id}}' 2>/dev/null || echo ""
}

# Check if network exists
is_network_exists() {
    local network="$1"
    docker network inspect "$network" >/dev/null 2>&1
}

# Create network if not exists
ensure_network() {
    local network="$1"
    if ! is_network_exists "$network"; then
        docker network create "$network" >/dev/null 2>&1
    fi
}

# Get volume size
get_volume_size() {
    local volume="$1"
    docker volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null | \
        xargs du -sh 2>/dev/null | cut -f1 || echo "0"
}

# Check disk space
check_disk_space() {
    local min_gb="${1:-20}"
    local available=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    
    if [[ "$available" -lt "$min_gb" ]]; then
        echo "Low disk space: ${available}GB available (minimum: ${min_gb}GB)"
        return 1
    fi
    return 0
}

# Check memory
check_memory() {
    local min_mb="${1:-2048}"
    local available=$(free -m | awk '/^Mem:/{print $7}')
    
    if [[ "$available" -lt "$min_mb" ]]; then
        echo "Low memory: ${available}MB available (minimum: ${min_mb}MB)"
        return 1
    fi
    return 0
}

# Prune unused Docker resources
docker_prune() {
    docker system prune -f >/dev/null 2>&1
}