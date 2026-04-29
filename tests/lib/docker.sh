#!/usr/bin/env bash
set -euo pipefail

docker_is_running() {
    docker info >/dev/null 2>&1
}

docker_compose_up() {
    local stack_dir="$1"
    docker compose -f "$stack_dir/docker-compose.yml" up -d 2>&1
}

docker_compose_down() {
    local stack_dir="$1"
    docker compose -f "$stack_dir/docker-compose.yml" down -v 2>&1
}

docker_container_ip() {
    local name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null | head -1
}

docker_container_logs() {
    local name="$1" tail="${2:-50}"
    docker logs --tail "$tail" "$name" 2>&1
}

docker_wait_healthy() {
    local name="$1" timeout="${2:-120}"
    local elapsed=0
    while (( elapsed < timeout )); do
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            return 0
        fi
        sleep 5
        (( elapsed += 5 )) || true
    done
    return 1
}

docker_service_count() {
    local stack_dir="$1"
    docker compose -f "$stack_dir/docker-compose.yml" config --services 2>/dev/null | wc -l | tr -d ' '
}