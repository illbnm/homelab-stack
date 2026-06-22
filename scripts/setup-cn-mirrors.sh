#!/usr/bin/env bash
set -euo pipefail

read -p "Are you located in Mainland China? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping mirror setup."
    exit 0
fi

echo "Configuring Docker registry mirrors..."
if command -v docker &> /dev/null; then
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

    sudo systemctl daemon-reload || true
    sudo systemctl restart docker || true

    echo "Testing docker pull hello-world..."
    if docker pull hello-world; then
        echo "Docker pull successful."
    else
        echo "Docker pull failed."
        exit 1
    fi
else
    echo "Docker not installed, skipping mirror setup."
fi
