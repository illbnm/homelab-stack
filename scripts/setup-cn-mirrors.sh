#!/bin/bash
# CN Mirror Setup - Docker registry mirrors
echo "Setting up Docker CN mirrors..."
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{"registry-mirrors":["https://mirror.gcr.io","https://docker.m.daocloud.io"]}
EOF
sudo systemctl restart docker
echo "Done!"
