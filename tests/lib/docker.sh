#!/usr/bin/env bash
# Docker utilities for HomeLab Stack test runner

get_container_health() {
    local name="$1"
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name" 2>/dev/null || echo "unknown"
}

is_port_listening() {
    local host="${1:-127.0.0.1}"
    local port="$2"
    nc -z -w 2 "$host" "$port" 2>/dev/null
}
