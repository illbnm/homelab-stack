#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — One-click diagnostic report
# Collects system info, container status, logs, network, config validation
# Usage: ./diagnose.sh [output-file]
# =============================================================================
set -euo pipefail

OUTPUT="${1:-diagnose-report.txt}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

{
    echo "========================================="
    echo " HomeLab Stack Diagnostic Report"
    echo " Generated: $(date -Iseconds)"
    echo "========================================="
    echo ""

    echo "--- System Info ---"
    uname -a
    echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 || echo unknown)"
    echo ""

    echo "--- Docker ---"
    docker version --format 'Server: {{.Server.Version}}' 2>/dev/null || echo "Docker not found"
    docker compose version 2>/dev/null || echo "Docker Compose not found"
    echo ""

    echo "--- Resources ---"
    free -h | head -2
    df -h / | tail -1
    echo ""

    echo "--- Container Status ---"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers"
    echo ""

    echo "--- Proxy Network ---"
    docker network inspect proxy --format '{{.Name}}: {{len .Containers}} containers' 2>/dev/null || echo "proxy network not found"
    echo ""

    echo "--- Recent Errors (last 100 lines) ---"
    docker ps -a --format '{{.Names}}' 2>/dev/null | while read -r c; do
        ERRORS=$(docker logs "$c" --since 1h 2>&1 | grep -iE 'error|fatal|panic|failed' | tail -20 || true)
        if [[ -n "$ERRORS" ]]; then
            echo "[$c]"
            echo "$ERRORS"
            echo ""
        fi
    done

    echo "--- Network Connectivity ---"
    for host in hub.docker.com ghcr.io gcr.io registry-1.docker.io; do
        if curl -sf --connect-timeout 3 "https://$host" >/dev/null 2>&1; then
            echo "  OK   $host"
        else
            echo "  FAIL $host"
        fi
    done
    echo ""

    echo "--- Compose Files ---"
    find "$PROJECT_DIR/stacks" -name "docker-compose.yml" | while read -r f; do
        if docker compose -f "$f" config --quiet 2>/dev/null; then
            echo "  OK   $f"
        else
            echo "  ERR  $f"
        fi
    done
    echo ""
    echo "========================================="
} > "$OUTPUT"

echo "Diagnostic report saved to: $OUTPUT"
