#!/usr/bin/env bash
# scripts/diagnose.sh
# Collects detailed system telemetry for reporting

REPORT_FILE="diagnose-report.txt"

{
    echo "=== HOMELAB STACK DIAGNOSTIC REPORT ==="
    echo "Date: $(date -u)"
    echo "OS: $(uname -a)"
    echo -e "\n--- Docker Version ---"
    docker version || true
    echo -e "\n--- Container Status ---"
    docker ps -a || true
    echo -e "\n--- Memory & Disk ---"
    free -m || true
    df -h / || true
} > "$REPORT_FILE"

echo "[✓] Diagnostic report generated at $REPORT_FILE"
