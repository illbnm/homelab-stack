#!/usr/bin/env bash
# =============================================================================
# Docker Compose Compatibility Wrapper
# Provides compatibility between Docker Compose v1 (docker-compose) and v2 (docker compose)
# Usage: Source this file in other scripts: source scripts/docker-compose-wrapper.sh
# =============================================================================

set -euo pipefail

# Detect Docker Compose version and set command
detect_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
        return 0
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
        return 0
    else
        echo "ERROR: Neither 'docker compose' (v2) nor 'docker-compose' (v1) found"
        echo "Please install Docker Compose"
        return 1
    fi
}

# Wrapper function for docker compose commands
dcc() {
    detect_docker_compose || return 1
    $DOCKER_COMPOSE "$@"
}

# Export for use in other scripts
export -f detect_docker_compose
export -f dcc

# If run directly, show version info
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_docker_compose
    echo "Using: $DOCKER_COMPOSE"
    $DOCKER_COMPOSE version
fi
