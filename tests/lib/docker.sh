#!/usr/bin/env bash
# Docker utility functions for tests
# Copyright (c) 2026 思捷娅科技 (SJYKJ) | License: MIT

docker_compose_up() {
    local stack="$1"
    local compose_file="stacks/${stack}/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        docker compose -f "$compose_file" up -d 2>&1
        return $?
    fi
    return 1
}

docker_compose_down() {
    local stack="$1"
    local compose_file="stacks/${stack}/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        docker compose -f "$compose_file" down 2>&1
        return $?
    fi
    return 1
}

wait_for_container() {
    local name="$1" timeout="${2:-60}"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done
    return 1
}

get_service_url() {
    local service="$1"
    local domain="${DOMAIN:-localhost}"
    echo "https://${service}.${domain}"
}

get_container_port() {
    local container="$1" port_internal="$2"
    docker port "$container" "$port_internal" 2>/dev/null | head -1 | cut -d: -f2
}
