#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    echo "Setting up Docker mirrors for China..."
    mirrors=("mirror.gcr.io" "docker.m.daocloud.io" "hub-mirror.c.163.com" "mirror.baidubce.com")
    mirror_config="{\"registry-mirrors\": ["
    for mirror in "${mirrors[@]}"; do
        mirror_config+="\"https://$mirror\", "
    done
    # Remove trailing comma and space, close JSON
    mirror_config="${mirror_config%, }]"
    echo "$mirror_config" | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl restart docker
    echo "Docker daemon restarted with new mirror configuration."
    echo "Testing Docker pull..."
    if sudo docker pull hello-world; then
        echo "Docker pull successful. Configuration verified."
    else
        echo "Docker pull failed. Please check your configuration."
    fi
else
    echo "Skipping Docker mirror setup."
fi

echo "Switching apt sources to Tsinghua..."
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo apt-get update
echo "Switching pip sources to Tsinghua..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

echo "Setup complete."