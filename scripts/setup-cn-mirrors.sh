#!/usr/bin/env bash
# Setup China mainland Docker mirror acceleration
set -euo pipefail

DAEMON_JSON="/etc/docker/daemon.json"

MIRRORS=(
  "https://mirror.gcr.io"
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
)

echo "=== Docker Mirror Setup (China Mainland) ==="
read -p "Are you in China mainland? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping mirror setup."
  exit 0
fi

# Build mirror list JSON
mirror_json=$(printf '"%s",' "${MIRRORS[@]}")
mirror_json="[${mirror_json%,}]"

# Write daemon.json
if [ -f "$DAEMON_JSON" ]; then
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak"
fi

cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": $mirror_json,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "✓ Written $DAEMON_JSON"

# Restart Docker
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
sleep 3

# Verify
echo "Verifying mirror setup..."
if docker pull hello-world &>/dev/null; then
  echo "✓ Docker pull successful with mirrors"
  docker rmi hello-world &>/dev/null || true
else
  echo "✗ Docker pull failed - check mirror configuration"
  exit 1
fi

echo "=== Mirror setup complete ==="
