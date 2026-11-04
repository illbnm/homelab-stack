#!/usr/bin/env bash
# install.sh
# Hardened, zero-dependency deployment bootstrap for HomeLab Stack

set -euo pipefail

curl_retry() {
    local max_attempts=3
    local delay=5
    for i in $(seq 1 $max_attempts); do
        if curl --connect-timeout 10 --max-time 60 "$@"; then
            return 0
        fi
        echo "Attempt $i failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
    done
    return 1
}

echo "[*] Validating prerequisites..."
if ! command -v docker >/dev/null 2>&1; then
    echo "[!] Docker not found. Installing via get.docker.com..."
    curl_retry -fsSL https://get.docker.com | sh
fi

echo "[*] Creating required networks..."
docker network create proxy 2>/dev/null || true
docker network create homelab-internal 2>/dev/null || true

echo "[*] Checking available disk space..."
AVAIL_KB=$(df / | awk 'NR==2 {print $4}')
if [ "$AVAIL_KB" -lt 5242880 ]; then
    echo "[!] ERROR: Less than 5GB disk space available!"
    exit 1
fi

echo "[✓] Environment verified and initialized successfully!"
