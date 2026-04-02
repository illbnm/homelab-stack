#!/bin/bash

wait_for_container() {
    local container="$1"
    local timeout="${2:-30}"
    
    for i in $(seq 1 $timeout); do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

get_container_port() {
    local container="$1"
    local port="${2:-80}"
    docker port "$container" "$port" 2>/dev/null | cut -d: -f2
}
