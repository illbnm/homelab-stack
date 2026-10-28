#!/usr/bin/env bash
set -euo pipefail

# HomeLab Stack: Unified Robust Installer
echo "================================================="
echo "        🚀 HomeLab Stack System Installer       "
echo "================================================="

curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    echo "Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}

# 1. System Resources & Prerequisite Checks
echo "[1/6] Inspecting Host Hardware & Resources..."
AVAIL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo 4096)
AVAIL_DISK_KB=$(df -k / | awk 'NR==2 {print $4}')
AVAIL_DISK_GB=$((AVAIL_DISK_KB / 1024 / 1024))

if [ "$AVAIL_RAM" -lt 2048 ]; then
  echo "⚠️ Warning: Low Available RAM (${AVAIL_RAM}MB < 2048MB). Lightweight profiles recommended."
fi

if [ "$AVAIL_DISK_GB" -lt 5 ]; then
  echo "❌ Fatal Error: Insufficient Disk Space (< 5GB free). Installation halted."
  exit 1
elif [ "$AVAIL_DISK_GB" -lt 20 ]; then
  echo "⚠️ Warning: Less than 20GB free disk space (${AVAIL_DISK_GB}GB). Consider cleanup."
fi

# 2. Port Conflict Checks
echo "[2/6] Checking Port Conflicts..."
CONFLICTS=0
for port in 80 443 53 3000 9000 8080; do
  if command -v ss >/dev/null 2>&1; then
    if ss -tuln | grep -q ":$port "; then
      echo "⚠️ Port $port is already in use by another process."
      CONFLICTS=$((CONFLICTS + 1))
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":$port "; then
      echo "⚠️ Port $port is already in use by another process."
      CONFLICTS=$((CONFLICTS + 1))
    fi
  fi
done

# 3. Docker & Compose V2 Engine Verification
echo "[3/6] Verifying Docker Engine & Docker Compose v2..."
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Installing Docker engine automatically..."
  if command -v apt-get >/dev/null 2>&1; then
    curl_retry -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
  elif command -v yum >/dev/null 2>&1; then
    curl_retry -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm docker docker-compose
  else
    echo "❌ Unsupported package manager. Please install Docker manually."
    exit 1
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "⚠️ Warning: Docker Compose V2 not found. Upgrading docker-compose-plugin..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin
  fi
fi

# 4. User Group Privileges
echo "[4/6] Configuring User Privileges..."
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ]; then
  if ! id -nG "$CURRENT_USER" | grep -qw "docker"; then
    echo "Adding user '$CURRENT_USER' to docker group..."
    sudo usermod -aG docker "$CURRENT_USER" || true
    echo "ℹ️ Please re-login or run 'newgrp docker' to apply group changes."
  fi
fi

# 5. Network Optimization & Connectivity Probe
echo "[5/6] Probing Network Connectivity..."
chmod +x ./scripts/*.sh
./scripts/check-connectivity.sh || true

# 6. Global Shared Docker Network
echo "[6/6] Ensuring External Proxy Network..."
docker network create proxy 2>/dev/null || true

echo "================================================="
echo "🎉 HomeLab Stack Installation Environment Ready!"
echo "Next step: Configure .env and run docker compose up -d"
echo "================================================="
