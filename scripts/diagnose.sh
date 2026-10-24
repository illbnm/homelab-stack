#!/usr/bin/env bash
# One-click system diagnostic reporter
REPORT="diagnose-report.txt"

{
    echo "================================================="
    echo " HOMELAB STACK DIAGNOSTIC REPORT"
    echo " Generated at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "================================================="
    echo ""
    echo "--- 1. OS & Kernel ---"
    uname -a
    echo ""
    echo "--- 2. Docker & Compose Versions ---"
    docker --version || echo "Docker missing"
    docker compose version || echo "Compose missing"
    echo ""
    echo "--- 3. Disk & Memory ---"
    df -h
    free -h
    echo ""
    echo "--- 4. Active Containers ---"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
} > "$REPORT"

echo "[OK] Diagnostic written to $REPORT"
cat "$REPORT"
