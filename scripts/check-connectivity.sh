#!/usr/bin/env bash
# Network connectivity test suite
set -e

probe() {
    local target="$1"
    local label="$2"
    local start=$(date +%s%N)
    if curl -s --connect-timeout 5 -o /dev/null "$target"; then
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        echo -e "[OK]   $label — latency ${dur}ms"
    else
        echo -e "[FAIL] $label — Connection timeout or unreachable"
    fi
}

echo "=== Network Connectivity Diagnostic ==="
probe "https://hub.docker.com" "Docker Hub (hub.docker.com)"
probe "https://github.com" "GitHub (github.com)"
probe "https://gcr.io" "Google Container Registry (gcr.io)"
probe "https://ghcr.io" "GitHub Container Registry (ghcr.io)"
