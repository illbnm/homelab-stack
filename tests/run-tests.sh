#!/bin/bash

# Simple test runner for HomeLab Stack
# Usage: ./tests/run-tests.sh <stack_name>

set -e
source ./tests/lib/assert.sh

STACK=$1

if [ -z "$STACK" ]; then
    echo "Usage: $0 <stack_name>"
    exit 1
fi

echo "Running tests for stack: $STACK"

case $STACK in
    base)
        # Verify containers are running
        for svc in traefik portainer watchtower; do
            status=$(docker inspect -f '{{.State.Running}}' $svc)
            assert_eq "$status" "true" "Container $svc is running"
        done
        ;;
    databases)
        # Verify DB health
        for svc in homelab-postgres homelab-redis homelab-mariadb; do
            status=$(docker inspect -f '{{.State.Health.Status}}' $svc)
            assert_eq "$status" "healthy" "Container $svc is healthy"
        done
        ;;
    *)
        echo "Unknown stack: $STACK"
        exit 1
        ;;
esac

echo "All tests passed for $STACK!"