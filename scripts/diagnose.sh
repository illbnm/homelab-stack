#!/bin/bash
# diagnose.sh - Generate homelab-stack diagnostic report
# Usage: ./diagnose.sh [--output <file>] [--stack <stack-name>]
#
# Collects system info, Docker status, container logs, and network diagnostics.
# Use this when seeking help or debugging deployment issues.
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

OUTPUT=""
STACK=""
REPORT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2;;
        --stack) STACK="$2"; shift 2;;
        *) shift;;
    esac
done

REPORT=$(mktemp)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$REPORT" << HEADER
================================================================================
                  HOMELAB STACK DIAGNOSTIC REPORT
================================================================================
Time: $TIMESTAMP
Hostname: $(hostname)
================================================================================

HEADER

# System Info
cat >> "$REPORT" << 'EOF'
## System Information
EOF
echo "Kernel: $(uname -sr)" >> "$REPORT"
echo "OS: $(uname -o)" >> "$REPORT"
echo "Architecture: $(uname -m)" >> "$REPORT"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)" >> "$REPORT"
echo "" >> "$REPORT"

# Disk
cat >> "$REPORT" << 'EOF'
## Disk Usage
EOF
df -h | grep -E "^/dev/" | awk '{print "  " $1 "  " $2 "  " $3 "  " $4 "  " $5 "  " $6}' >> "$REPORT"
echo "" >> "$REPORT"

# Memory
cat >> "$REPORT" << 'EOF'
## Memory Usage
EOF
free -h | awk 'NR==1{print "  " $0} NR==2{print "  " $0} NR==3{print "  " $0}' >> "$REPORT"
echo "" >> "$REPORT"

# Docker
cat >> "$REPORT" << 'EOF'
## Docker Information
EOF
if command -v docker &> /dev/null; then
    echo "Docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'not running')" >> "$REPORT"
    echo "Compose: $(docker compose version 2>/dev/null || docker-compose version 2>/dev/null || echo 'unknown')" >> "$REPORT"
    echo "" >> "$REPORT"

    cat >> "$REPORT" << 'EOF'
## Docker Status
EOF
    if systemctl is-active docker &> /dev/null; then
        echo "Docker daemon: active" >> "$REPORT"
    else
        echo "Docker daemon: NOT ACTIVE" >> "$REPORT"
    fi

    # Daemon config
    echo "" >> "$REPORT"
    echo "Registry mirrors configured:" >> "$REPORT"
    if [[ -f /etc/docker/daemon.json ]]; then
        cat /etc/docker/daemon.json | jq '.' 2>/dev/null | sed 's/^/  /' >> "$REPORT" || sed 's/^/  /' /etc/docker/daemon.json >> "$REPORT"
    else
        echo "  (none configured)" >> "$REPORT"
    fi
    echo "" >> "$REPORT"
else
    echo "Docker: NOT INSTALLED" >> "$REPORT"
    echo "" >> "$REPORT"
fi

# Containers
if [[ -n "$STACK" ]]; then
    cat >> "$REPORT" << EOF

## Stack: $STACK
EOF
    echo "Container Status:" >> "$REPORT"
    docker compose -p "$STACK" ps 2>/dev/null | sed 's/^/  /' >> "$REPORT" || \
    docker-compose -p "$STACK" ps 2>/dev/null | sed 's/^/  /' >> "$REPORT" || \
    echo "  (could not get status)" >> "$REPORT"
    echo "" >> "$REPORT"

    cat >> "$REPORT" << EOF

## Recent Logs: $STACK
EOF
    docker compose -p "$STACK" logs --tail=30 2>/dev/null | sed 's/^/  /' >> "$REPORT" || \
    echo "  (no logs available)" >> "$REPORT"
    echo "" >> "$REPORT"
else
    cat >> "$REPORT" << 'EOF'

## All Containers
EOF
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | sed 's/^/  /' >> "$REPORT" || \
    echo "  (docker not accessible)" >> "$REPORT"
    echo "" >> "$REPORT"
fi

# Network
cat >> "$REPORT" << 'EOF'

## Network Connectivity
EOF
check_net() {
    local name="$1"; local url="$2"
    echo -n "  $name: " >> "$REPORT"
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo "OK" >> "$REPORT"
    else
        echo "FAIL" >> "$REPORT"
    fi
}
check_net "GitHub"       "https://github.com"
check_net "Docker Hub"    "https://hub.docker.com"
check_net "gcr.io"       "https://gcr.io"
check_net "ghcr.io"      "https://ghcr.io"
check_net "DaoCloud"     "https://docker.m.daocloud.io"
check_net "Baidu Mirror"  "https://mirror.baidubce.com"
echo "" >> "$REPORT"

# Files
cat >> "$REPORT" << 'EOF'

## homelab-stack Files
EOF
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
if [[ -d "$PROJECT_ROOT" ]]; then
    echo "  Project root: $PROJECT_ROOT" >> "$REPORT"
    echo "  Compose files:" >> "$REPORT"
    find "$PROJECT_ROOT" \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) 2>/dev/null | sed 's/^/    /' >> "$REPORT"
    echo "  Scripts:" >> "$REPORT"
    find "$PROJECT_ROOT/scripts" -maxdepth 1 -type f -name "*.sh" 2>/dev/null | sort | sed 's/^/    /' >> "$REPORT"
else
    echo "  Project directory not found: $PROJECT_ROOT" >> "$REPORT"
fi
echo "" >> "$REPORT"

cat >> "$REPORT" << 'EOF'

## Environment Variables (non-sensitive)
EOF
env | grep -vE '(PASSWORD|SECRET|TOKEN|KEY|API)' | grep -E '^(HOMELAB|DOCKER|COMPOSE|NGINX|POSTGRES|REDIS)' | sed 's/^/  /' >> "$REPORT" || \
echo "  (none set)" >> "$REPORT"
echo "" >> "$REPORT"

cat >> "$REPORT" << EOF

================================================================================
                         END OF DIAGNOSTIC REPORT
================================================================================
EOF

# Output
if [[ -n "$OUTPUT" ]]; then
    cp "$REPORT" "$OUTPUT"
    echo "Report saved to: $OUTPUT"
fi

cat "$REPORT"
rm -f "$REPORT"
