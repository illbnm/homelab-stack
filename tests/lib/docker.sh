#!/bin/bash
# docker.sh - Docker utility functions for tests

# Get container status
docker_container_status() {
    local container_name="$1"
    docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found"
}

# Get container health status
docker_container_health() {
    local container_name="$1"
    docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none"
}

# Check if container is running
docker_is_running() {
    local container_name="$1"
    local status=$(docker_container_status "$container_name")
    [ "$status" = "running" ]
}

# Check if container is healthy
docker_is_healthy() {
    local container_name="$1"
    local health=$(docker_container_health "$container_name")
    [ "$health" = "healthy" ]
}

# Get container IP
docker_container_ip() {
    local container_name="$1"
    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null || echo ""
}

# Get container port
docker_container_port() {
    local container_name="$1"
    local internal_port="$2"
    docker port "$container_name" "$internal_port" 2>/dev/null | cut -d':' -f2 || echo ""
}

# Execute command in container
docker_exec() {
    local container_name="$1"
    shift
    docker exec "$container_name" "$@" 2>/dev/null
}

# Get container logs
docker_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    docker logs --tail "$lines" "$container_name" 2>&1
}

# Wait for container to be healthy
docker_wait_healthy() {
    local container_name="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if docker_is_healthy "$container_name"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 1
}

# Wait for container to be running
docker_wait_running() {
    local container_name="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if docker_is_running "$container_name"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 1
}

# Get container labels
docker_get_label() {
    local container_name="$1"
    local label="$2"
    docker inspect --format="{{index .Config.Labels \"$label\"}}" "$container_name" 2>/dev/null || echo ""
}

# Get all container names for a stack
docker_stack_containers() {
    local stack_name="$1"
    docker ps --format '{{.Names}}' | grep "^${stack_name}-" || echo ""
}

# Check if volume exists
docker_volume_exists() {
    local volume_name="$1"
    docker volume inspect "$volume_name" >/dev/null 2>&1
}

# Get container env var
docker_get_env() {
    local container_name="$1"
    local var_name="$2"
    docker exec "$container_name" printenv "$var_name" 2>/dev/null || echo ""
}

# Network functions
docker_network_exists() {
    local network_name="$1"
    docker network inspect "$network_name" >/dev/null 2>&1
}

docker_get_network_mode() {
    local container_name="$1"
    docker inspect --format='{{.HostConfig.NetworkMode}}' "$container_name" 2>/dev/null || echo ""
}

# Compose functions
docker_compose_config() {
    local compose_file="$1"
    docker compose -f "$compose_file" config --quiet 2>&1
}

docker_compose_validate() {
    local compose_file="$1"
    docker compose -f "$compose_file" config >/dev/null 2>&1
}

# Export functions
export -f docker_container_status docker_container_health
export -f docker_is_running docker_is_healthy
export -f docker_container_ip docker_container_port
export -f docker_exec docker_logs
export -f docker_wait_healthy docker_wait_running
export -f docker_get_label docker_stack_containers
export -f docker_volume_exists docker_get_env
export -f docker_network_exists docker_get_network_mode
export -f docker_compose_config docker_compose_validate
