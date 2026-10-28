#!/usr/bin/env bash
set -u

OUT_FILE="diagnose-report.txt"
echo "Generating HomeLab Stack Diagnostic Report into $OUT_FILE..."

{
  echo "================================================================"
  echo "             HOMELAB STACK DIAGNOSTIC REPORT                   "
  echo "             Generated: $(date -u)                            "
  echo "================================================================"
  echo ""
  echo "### 1. SYSTEM INFORMATION"
  uname -a 2>/dev/null || true
  if [ -f /etc/os-release ]; then
    cat /etc/os-release
  fi
  echo ""
  echo "### 2. HARDWARE RESOURCES"
  echo "--- Memory ---"
  free -m 2>/dev/null || true
  echo "--- Disk Space ---"
  df -h / 2>/dev/null || true
  echo ""
  echo "### 3. DOCKER ENVIRONMENT"
  docker version 2>/dev/null || echo "Docker not accessible"
  docker compose version 2>/dev/null || echo "Compose V2 not accessible"
  echo ""
  echo "### 4. RUNNING CONTAINERS"
  docker ps --format "table {{.Names}}	{{.Status}}	{{.Ports}}" 2>/dev/null || true
  echo ""
  echo "### 5. DOCKER NETWORKS"
  docker network ls 2>/dev/null || true
  echo ""
  echo "### 6. NETWORK CONNECTIVITY"
  if [ -f "./scripts/check-connectivity.sh" ]; then
    ./scripts/check-connectivity.sh 2>&1 || true
  fi
  echo ""
  echo "### 7. RECENT ERROR LOGS FROM DOCKER"
  docker ps -q 2>/dev/null | while read -r cid; do
    cname=$(docker inspect --format='{{.Name}}' "$cid")
    errors=$(docker logs --tail 100 "$cid" 2>&1 | grep -iE 'error|fatal|exception' | tail -n 5 || true)
    if [ -n "$errors" ]; then
      echo "Container $cname errors:"
      echo "$errors"
      echo "---"
    fi
  done
  echo "================================================================"
} > "$OUT_FILE"

cat "$OUT_FILE"
echo " [SUCCESS] Diagnostic report saved to $(pwd)/$OUT_FILE"
