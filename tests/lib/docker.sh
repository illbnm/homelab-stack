#!/usr/bin/env bash
# =============================================================================
# Docker Utility Functions — HomeLab Stack Integration Tests
# =============================================================================

# Get container status (running, exited, etc.)
container_status() {
    local name="$1"
    docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "missing"
}

# Get container health status
container_health() {
    local name="$1"
    docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck"
}

# Get container image
container_image() {
    local name="$1"
    docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo "unknown"
}

# Check if container is running
is_container_running() {
    local name="$1"
    [[ "$(container_status "$name")" == "running" ]]
}

# Wait for container to be healthy (or running if no healthcheck)
wait_container_healthy() {
    local name="$1"
    local timeout="${2:-120}"
    local interval="${3:-5}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        local status health
        status=$(container_status "$name")
        health=$(container_health "$name")

        if [[ "$status" == "running" ]] && \
           [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 1
}

# Get container logs (last N lines)
container_logs() {
    local name="$1"
    local lines="${2:-50}"
    docker logs --tail "$lines" "$name" 2>&1
}

# Execute command inside container
container_exec() {
    local name="$1"
    shift
    docker exec "$name" "$@" 2>&1
}

# Get container IP
container_ip() {
    local name="$1"
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null
}

# Check if image exists locally
image_exists() {
    local image="$1"
    docker image inspect "$image" &>/dev/null
}

# Pull image
pull_image() {
    local image="$1"
    echo "Pulling image: $image"
    docker pull "$image" 2>&1
}

# Get list of containers by label
containers_by_label() {
    local label="$1"
    docker ps --filter "label=$label" --format '{{.Names}}' 2>/dev/null
}

# Get list of all homelab containers
all_homelab_containers() {
    docker ps --filter "com.homelab.stack=true" --format '{{.Names}}' 2>/dev/null
}

# Get compose project name from directory
compose_project_name() {
    local compose_dir="$1"
    basename "$(dirname "$compose_dir")"
}
