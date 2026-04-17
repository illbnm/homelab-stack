#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Test Utilities
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Container queries
# ---------------------------------------------------------------------------

container_exists() {
    docker inspect "$1" >/dev/null 2>&1
}

container_running() {
    [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

container_health() {
    docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null || echo "none"
}

container_uptime_seconds() {
    local started
    started=$(docker inspect -f '{{.State.StartedAt}}' "$1" 2>/dev/null || echo "")
    if [[ -z "$started" ]]; then echo "0"; return; fi
    local start_epoch end_epoch
    start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
    end_epoch=$(date +%s)
    echo $((end_epoch - start_epoch))
}

container_restart_count() {
    docker inspect -f '{{.RestartCount}}' "$1" 2>/dev/null || echo "0"
}

container_image() {
    docker inspect -f '{{.Config.Image}}' "$1" 2>/dev/null || echo ""
}

container_port_bindings() {
    docker inspect -f '{{json .NetworkSettings.Ports}}' "$1" 2>/dev/null || echo "{}"
}

# ---------------------------------------------------------------------------
# Stack operations
# ---------------------------------------------------------------------------

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
STACKS_DIR="$BASE_DIR/stacks"

get_compose_file() {
    local stack="$1"
    if [[ -f "$STACKS_DIR/$stack/docker-compose.local.yml" ]]; then
        echo "$STACKS_DIR/$stack/docker-compose.local.yml"
    elif [[ -f "$STACKS_DIR/$stack/docker-compose.yml" ]]; then
        echo "$STACKS_DIR/$stack/docker-compose.yml"
    else
        return 1
    fi
}

list_stack_services() {
    local compose_file
    compose_file=$(get_compose_file "$1") || return 1
    docker compose -f "$compose_file" config --services 2>/dev/null
}

stack_is_running() {
    local compose_file
    compose_file=$(get_compose_file "$1") || return 1
    local running
    running=$(docker compose -f "$compose_file" ps --status running -q 2>/dev/null | wc -l)
    [[ "$running" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# Network / service discovery
# ---------------------------------------------------------------------------

service_port() {
    local container="$1"
    docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} {{end}}' "$container" 2>/dev/null \
        | grep -oP '\d+(?=/tcp)' | head -1
}

wait_for_healthy() {
    local container="$1" timeout="${2:-60}" elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(container_health "$container")
        if [[ "$health" == "healthy" ]]; then return 0; fi
        sleep 2; elapsed=$((elapsed + 2))
    done
    return 1
}

wait_for_port() {
    local host="${1:-localhost}" port="$2" timeout="${3:-30}" elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if (echo >/dev/tcp/$host/$port) 2>/dev/null; then return 0; fi
        sleep 1; elapsed=$((elapsed + 1))
    done
    return 1
}
