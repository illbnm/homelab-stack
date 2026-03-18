#!/bin/bash

# Docker utility functions for container status checks and health verification

# Check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "ERROR: Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Wait for container to be running
wait_for_container() {
    local container_name="$1"
    local timeout="${2:-30}"
    local count=0
    
    echo "Waiting for container '$container_name' to be running..."
    
    while [ $count -lt $timeout ]; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
            echo "Container '$container_name' is running"
            return 0
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "ERROR: Container '$container_name' failed to start within $timeout seconds"
    return 1
}

# Wait for container to be healthy
wait_for_healthy() {
    local container_name="$1"
    local timeout="${2:-60}"
    local count=0
    
    echo "Waiting for container '$container_name' to be healthy..."
    
    while [ $count -lt $timeout ]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        
        if [ "$health" = "healthy" ]; then
            echo "Container '$container_name' is healthy"
            return 0
        elif [ "$health" = "unhealthy" ]; then
            echo "ERROR: Container '$container_name' is unhealthy"
            return 1
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "ERROR: Container '$container_name' health check timed out after $timeout seconds"
    return 1
}

# Check if port is accessible
check_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-10}"
    
    if [ -z "$port" ]; then
        echo "ERROR: Port not specified"
        return 1
    fi
    
    echo "Checking if port $port is accessible on $host..."
    
    if command -v nc &> /dev/null; then
        if nc -z "$host" "$port" -w "$timeout" 2>/dev/null; then
            echo "Port $port is accessible on $host"
            return 0
        fi
    elif command -v telnet &> /dev/null; then
        if timeout "$timeout" telnet "$host" "$port" &>/dev/null; then
            echo "Port $port is accessible on $host"
            return 0
        fi
    else
        # Fallback using bash TCP redirection
        if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            echo "Port $port is accessible on $host"
            return 0
        fi
    fi
    
    echo "ERROR: Port $port is not accessible on $host"
    return 1
}

# Get container IP address
get_container_ip() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        echo "ERROR: Container name not specified"
        return 1
    fi
    
    local ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null)
    
    if [ -z "$ip" ]; then
        echo "ERROR: Could not get IP address for container '$container_name'"
        return 1
    fi
    
    echo "$ip"
    return 0
}

# Get container port mapping
get_container_port() {
    local container_name="$1"
    local internal_port="$2"
    
    if [ -z "$container_name" ] || [ -z "$internal_port" ]; then
        echo "ERROR: Container name and internal port must be specified"
        return 1
    fi
    
    local port=$(docker port "$container_name" "$internal_port" 2>/dev/null | cut -d: -f2)
    
    if [ -z "$port" ]; then
        echo "ERROR: Could not get port mapping for container '$container_name' port '$internal_port'"
        return 1
    fi
    
    echo "$port"
    return 0
}

# Execute command in container
exec_in_container() {
    local container_name="$1"
    shift
    local command="$*"
    
    if [ -z "$container_name" ] || [ -z "$command" ]; then
        echo "ERROR: Container name and command must be specified"
        return 1
    fi
    
    docker exec "$container_name" sh -c "$command"
}

# Check container logs for pattern
check_logs_for_pattern() {
    local container_name="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local count=0
    
    if [ -z "$container_name" ] || [ -z "$pattern" ]; then
        echo "ERROR: Container name and pattern must be specified"
        return 1
    fi
    
    echo "Checking logs for pattern '$pattern' in container '$container_name'..."
    
    while [ $count -lt $timeout ]; do
        if docker logs "$container_name" 2>&1 | grep -q "$pattern"; then
            echo "Pattern '$pattern' found in logs"
            return 0
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "ERROR: Pattern '$pattern' not found in logs within $timeout seconds"
    return 1
}

# Wait for service to be ready
wait_for_service() {
    local service_url="$1"
    local timeout="${2:-60}"
    local expected_status="${3:-200}"
    local count=0
    
    if [ -z "$service_url" ]; then
        echo "ERROR: Service URL must be specified"
        return 1
    fi
    
    echo "Waiting for service at '$service_url' to be ready..."
    
    while [ $count -lt $timeout ]; do
        if command -v curl &> /dev/null; then
            local status=$(curl -s -o /dev/null -w "%{http_code}" "$service_url" 2>/dev/null || echo "000")
            if [ "$status" = "$expected_status" ]; then
                echo "Service at '$service_url' is ready (HTTP $status)"
                return 0
            fi
        elif command -v wget &> /dev/null; then
            if wget --spider --quiet "$service_url" 2>/dev/null; then
                echo "Service at '$service_url' is ready"
                return 0
            fi
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "ERROR: Service at '$service_url' is not ready after $timeout seconds"
    return 1
}

# Clean up containers by pattern
cleanup_containers() {
    local pattern="$1"
    
    if [ -z "$pattern" ]; then
        echo "ERROR: Container name pattern must be specified"
        return 1
    fi
    
    echo "Cleaning up containers matching pattern '$pattern'..."
    
    local containers=$(docker ps -a --format "{{.Names}}" | grep "$pattern" || true)
    
    if [ -n "$containers" ]; then
        echo "Stopping and removing containers: $containers"
        echo "$containers" | xargs -r docker rm -f
        echo "Cleanup completed"
    else
        echo "No containers found matching pattern '$pattern'"
    fi
    
    return 0
}

# Get container status
get_container_status() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        echo "ERROR: Container name must be specified"
        return 1
    fi
    
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [ -z "$status" ]; then
        echo "not_found"
        return 1
    fi
    
    echo "$status"
    return 0
}

# Check if container exists
container_exists() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        return 1
    fi
    
    docker inspect "$container_name" &>/dev/null
}

# Get container resource usage
get_container_stats() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        echo "ERROR: Container name must be specified"
        return 1
    fi
    
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$container_name"
}