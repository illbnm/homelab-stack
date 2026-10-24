#!/usr/bin/env bash
# Configure Docker registry mirrors for high reliability
set -e

DAEMON_JSON="/etc/docker/daemon.json"

echo "=== Configuring Docker CN Acceleration Mirrors ==="

sudo mkdir -p /etc/docker

cat << 'EOF' | sudo tee "$DAEMON_JSON" > /dev/null
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.baidubce.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.gcr.io"
  ]
}
EOF

echo "[*] Restarting Docker daemon..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "[*] Testing mirror pull..."
docker pull hello-world > /dev/null && echo "[OK] Docker acceleration verified!"
