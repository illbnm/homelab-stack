#!/usr/bin/env bash
# docker.sh - Docker utility functions for homelab-stack tests
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

# Project root detection
_DOCKER_ROOT="${DOCKER_ROOT:-/tmp/homelab-stack}"
_COMPOSE_DIR="${_COMPOSE_DIR:-${_DOCKER_ROOT}}"

# Set compose directory (call before other functions)
docker_set_compose_dir() {
    _COMPOSE_DIR="$1"
}

# Get compose file path for a stack
get_compose_file() {
    local stack="$1"
    local candidates=(
        "${_COMPOSE_DIR}/${stack}/docker-compose.yml"
        "${_COMPOSE_DIR}/${stack}/docker-compose.yaml"
        "${_COMPOSE_DIR}/docker-compose.${stack}.yml"
        "${_COMPOSE_DIR}/docker-compose.${stack}.yaml"
    )
    for f in "${candidates[@]}"; do
        if [ -f "$f" ]; then
            echo "$f"
            return 0
        fi
    done
    echo ""
    return 1
}

# Get list of services from a compose file
get_stack_services() {
    local stack="$1"
    local compose_file
    compose_file=$(get_compose_file "$stack")
    if [ -z "$compose_file" ] || [ ! -f "$compose_file" ]; then
        echo "ERROR: compose file not found for stack '${stack}'" >&2
        return 1
    fi
    # Parse top-level service names
    local in_services=false
    while IFS= read -r line; do
        # Remove leading whitespace
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
        if [ "$trimmed" = "services:" ]; then
            in_services=true
            continue
        fi
        if $in_services; then
            # Stop at next top-level key
            if [[ "$trimmed" =~ ^[a-z_]+: ]] && [[ ! "$trimmed" =~ ^[[:space:]] ]]; then
                if [ "$trimmed" != "services:" ]; then
                    break
                fi
            fi
            # Extract service name (key ending with colon, indented)
            if [[ "$trimmed" =~ ^[a-z0-9_-]+:$ ]]; then
                echo "${trimmed%:}"
            fi
        fi
    done < "$compose_file"
}

# Wait for container to become healthy
wait_for_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local elapsed=0
    local interval=2

    echo "  Waiting for ${container} to become healthy (timeout: ${timeout}s)..."

    while [ "$elapsed" -lt "$timeout" ]; do
        local status
        status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null) || true
        case "$status" in
            healthy)
                echo "  ✓ ${container} is healthy after ${elapsed}s"
                return 0
                ;;
            unhealthy)
                echo "  ✗ ${container} is unhealthy after ${elapsed}s"
                return 1
                ;;
            "")
                # No healthcheck or container not found
                local running
                running=$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null) || true
                if [ "$running" = "true" ]; then
                    echo "  ✓ ${container} is running (no healthcheck) after ${elapsed}s"
                    return 0
                fi
                ;;
        esac
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    echo "  ✗ Timeout waiting for ${container} after ${timeout}s"
    return 1
}

# Get container IP address
get_container_ip() {
    local container="$1"
    local network="${2:-}"
    if [ -n "$network" ]; then
        docker inspect --format "{{.NetworkSettings.Networks.${network}.IPAddress}}" "$container" 2>/dev/null || echo ""
    else
        docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null | head -1 || echo ""
    fi
}

# Get container logs
get_container_logs() {
    local container="$1"
    local lines="${2:-50}"
    docker logs --tail "$lines" "$container" 2>&1 || echo "ERROR: could not get logs for ${container}"
}

# Check if docker is available
docker_check() {
    if ! command -v docker &>/dev/null; then
        echo "ERROR: docker command not found" >&2
        return 1
    fi
    if ! docker info &>/dev/null; then
        echo "ERROR: docker daemon not running" >&2
        return 1
    fi
    return 0
}

# Check if docker compose is available
docker_compose_check() {
    if docker compose version &>/dev/null; then
        return 0
    elif command -v docker-compose &>/dev/null; then
        return 0
    else
        echo "ERROR: docker compose not available" >&2
        return 1
    fi
}

# Get the docker compose command (handles both plugins and standalone)
docker_compose_cmd() {
    if docker compose version &>/dev/null 2>&1; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}
