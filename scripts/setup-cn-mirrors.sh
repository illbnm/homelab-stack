#!/usr/bin/env bash
set -euo pipefail

# Setup Docker registry mirrors for China mainland network optimization
echo "=== HomeLab Stack: Docker Registry Mirror Setup ==="

NON_INTERACTIVE=${1:-""}
ENABLE_CN="n"

if [ "$NON_INTERACTIVE" = "--yes" ] || [ "$NON_INTERACTIVE" = "-y" ]; then
  ENABLE_CN="y"
else
  read -r -p "Configure Docker registry mirrors for China mainland? [y/N]: " answer
  case "$answer" in
    [yY][eE][sS]|[yY]) ENABLE_CN="y" ;;
    *) ENABLE_CN="n" ;;
  esac
fi

if [ "$ENABLE_CN" != "y" ]; then
  echo "Skipping mirror configuration."
  exit 0
fi

DAEMON_JSON="/etc/docker/daemon.json"
echo "Backing up existing $DAEMON_JSON if present..."
if [ -f "$DAEMON_JSON" ]; then
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%s)"
fi

mkdir -p /etc/docker

cat <<EOF > "$DAEMON_JSON"
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.baidubce.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.gcr.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF

echo "Restarting Docker daemon..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl restart docker
elif command -v service >/dev/null 2>&1; then
  service docker restart
fi

echo "Verifying Docker pull through mirror..."
if docker pull hello-world >/dev/null 2>&1; then
  echo " [SUCCESS] Docker mirror configured and verified successfully!"
else
  echo " [WARNING] 'docker pull hello-world' failed. Check your network or firewall."
fi
