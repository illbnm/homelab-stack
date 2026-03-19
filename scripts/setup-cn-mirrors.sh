#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    echo "Setting up Docker mirrors for China..."
    mirrors=("mirror.gcr.io" "docker.m.daocloud.io" "hub-mirror.c.163.com" "mirror.baidubce.com")
    daemon_config="/etc/docker/daemon.json"

    if [[ -f "$daemon_config" ]]; then
        cp "$daemon_config" "$daemon_config.bak"
    fi

    echo "{" > "$daemon_config"
    echo '  "registry-mirrors": [' >> "$daemon_config"
    for mirror in "${mirrors[@]}"; do
        echo "    \"$mirror\"," >> "$daemon_config"
    done
    sed -i '$ s/,$//' "$daemon_config"
    echo "  ]" >> "$daemon_config"
    echo "}" >> "$daemon_config"

    systemctl restart docker

    echo "Testing Docker pull..."
    if docker pull hello-world; then
        echo "Docker pull successful!"
    else
        echo "Docker pull failed. Please check your configuration."
    fi
else
    echo "Skipping Docker mirror setup."
fi
