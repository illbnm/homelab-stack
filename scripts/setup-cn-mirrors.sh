#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    mirrors=("mirror.gcr.io" "docker.m.daocloud.io" "hub-mirror.c.163.com" "mirror.baidubce.com")
    echo "Select a mirror:"
    for i in "${!mirrors[@]}"; do
        echo "$((i+1)): ${mirrors[$i]}"
    done
    read -r choice
    selected_mirror="${mirrors[$((choice-1))]}"

    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    fi

    echo "{\"registry-mirrors\": [\"https://$selected_mirror\"]}" | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker

    echo "Testing Docker pull with hello-world..."
    if docker pull hello-world; then
        echo "Docker pull successful!"
    else
        echo "Docker pull failed. Please check your configuration."
    fi
else
    echo "Skipping mirror setup."
fi