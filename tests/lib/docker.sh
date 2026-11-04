#!/usr/bin/env bash
# tests/lib/docker.sh
# Docker utility functions

get_container_ip() {
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null
}

cleanup_stack() {
    local compose_file="$1"
    docker compose -f "$compose_file" down -v --remove-orphans >/dev/null 2>&1 || true
}
