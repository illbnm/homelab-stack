#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" != "y" ]]; then
  echo "Skipping mirror setup."
  exit 0
fi

MIRRORS=(
  "mirror.gcr.io"
  "docker.m.daocloud.io"
  "hub-mirror.c.163.com"
  "mirror.baidubce.com"
)

for mirror in "${MIRRORS[@]}"; do
  echo "Testing mirror: $mirror"
  if curl -s --connect-timeout 5 --max-time 10 "https://$mirror" &> /dev/null; then
    SELECTED_MIRROR=$mirror
    break
  fi
done

if [[ -z "$SELECTED_MIRROR" ]]; then
  echo "No mirror is reachable. Please check your network connection."
  exit 1
fi

echo "Using mirror: $SELECTED_MIRROR"

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": ["https://$SELECTED_MIRROR"]
}
EOF

sudo systemctl restart docker

echo "Testing Docker pull with hello-world..."
if docker pull hello-world; then
  echo "Docker pull successful."
else
  echo "Docker pull failed. Please check your configuration."
  exit 1
fi