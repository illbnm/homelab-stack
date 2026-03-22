#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    echo "Setting up Docker mirrors for China..."
    mirrors=(
        "mirror.gcr.io"
        "docker.m.daocloud.io"
        "hub-mirror.c.163.com"
        "mirror.baidubce.com"
    )

    daemon_json="/etc/docker/daemon.json"
    if [[ -f "$daemon_json" ]]; then
        cp "$daemon_json" "$daemon_json.bak"
    fi

    echo "{" > "$daemon_json"
    echo '  "registry-mirrors": [' >> "$daemon_json"
    for mirror in "${mirrors[@]}"; do
        echo "    \"$mirror\"," >> "$daemon_json"
    done
    # Remove the trailing comma and close the JSON object
    sed -i '$ s/,$//' "$daemon_json"
    echo "  ]" >> "$daemon_json"
    echo "}" >> "$daemon_json"

    systemctl restart docker

    echo "Testing Docker pull with hello-world..."
    if docker pull hello-world; then
        echo "Docker mirror setup successful."
    else
        echo "Failed to pull hello-world. Check your configuration."
    fi
else
    echo "Skipping Docker mirror setup."
fi