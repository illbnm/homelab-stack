#!/bin/bash

# Docker utility functions for HomeLab Stack testing

# Check if a container is running
is_container_running() {
    local container_name="$1"
    [ "$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)" = "true" ]
}

# Check if a container exists
container_exists() {
    local container_name="$1"
    docker inspect "$container_name" >/dev/null 2>&1
}

# Get container status
get_container_status() {
    local container_name="$1"
    docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "not-found"
}

# Check if container is healthy (if health check is configured)
is_container_healthy() {
    local container_name="$1"
    local health_status
    health_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    [ "$health_status" = "healthy" ] || [ "$health_status" = "" ]
}

# Get container restart count
get_container_restart_count() {
    local container_name="$1"
    docker inspect -f '{{.RestartCount}}' "$container_name" 2>/dev/null || echo "0"
}

# Wait for container to be running
wait_for_container_running() {
    local container_name="$1"
    local timeout="${2:-30}"
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if is_container_running "$container_name"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

# Wait for container to be healthy
wait_for_container_healthy() {
    local container_name="$1"
    local timeout="${2:-60}"
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if is_container_healthy "$container_name"; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

# Get container logs
get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    docker logs --tail "$lines" "$container_name" 2>&1
}

# Get container logs since specific time
get_container_logs_since() {
    local container_name="$1"
    local since="${2:-5m}"
    docker logs --since "$since" "$container_name" 2>&1
}

# Check if Docker Compose service is running
is_compose_service_running() {
    local compose_file="$1"
    local service_name="$2"
    local project_name="${3:-}"

    local cmd="docker-compose -f $compose_file"
    if [ -n "$project_name" ]; then
        cmd="$cmd -p $project_name"
    fi

    local status
    status=$($cmd ps -q "$service_name" 2>/dev/null)
    [ -n "$status" ] && is_container_running "$status"
}

# Start Docker Compose services
start_compose_services() {
    local compose_file="$1"
    local project_name="${2:-}"

    local cmd="docker-compose -f $compose_file"
    if [ -n "$project_name" ]; then
        cmd="$cmd -p $project_name"
    fi

    $cmd up -d
}

# Stop Docker Compose services
stop_compose_services() {
    local compose_file="$1"
    local project_name="${2:-}"

    local cmd="docker-compose -f $compose_file"
    if [ -n "$project_name" ]; then
        cmd="$cmd -p $project_name"
    fi

    $cmd down
}

# Get Docker Compose service container name
get_compose_container_name() {
    local compose_file="$1"
    local service_name="$2"
    local project_name="${3:-}"

    local cmd="docker-compose -f $compose_file"
    if [ -n "$project_name" ]; then
        cmd="$cmd -p $project_name"
    fi

    $cmd ps -q "$service_name" 2>/dev/null | head -1
}

# Wait for all compose services to be running
wait_for_compose_services() {
    local compose_file="$1"
    local timeout="${2:-120}"
    local project_name="${3:-}"
    local elapsed=0

    local cmd="docker-compose -f $compose_file"
    if [ -n "$project_name" ]; then
        cmd="$cmd -p $project_name"
    fi

    while [ $elapsed -lt $timeout ]; do
        local services
        services=$($cmd config --services)
        local all_running=true

        for service in $services; do
            if ! is_compose_service_running "$compose_file" "$service" "$project_name"; then
                all_running=false
                break
            fi
        done

        if [ "$all_running" = true ]; then
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

# Get container port mapping
get_container_port() {
    local container_name="$1"
    local internal_port="$2"
    docker port "$container_name" "$internal_port" 2>/dev/null | cut -d':' -f2
}

# Check if container has specific port exposed
container_has_port() {
    local container_name="$1"
    local port="$2"
    docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}} {{end}}{{end}}' "$container_name" 2>/dev/null | grep -q "${port}/"
}

# Get container IP address
get_container_ip() {
    local container_name="$1"
    local network="${2:-bridge}"
    docker inspect -f "{{.NetworkSettings.Networks.${network}.IPAddress}}" "$container_name" 2>/dev/null
}

# Check container resource usage
get_container_stats() {
    local container_name="$1"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "$container_name" 2>/dev/null
}
