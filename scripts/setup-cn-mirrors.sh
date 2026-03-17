#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    echo "Setting up Docker mirrors for China..."
    MIRRORS=(
        "mirror.gcr.io"
        "docker.m.daocloud.io"
        "hub-mirror.c.163.com"
        "mirror.baidubce.com"
    )

    DAEMON_JSON="/etc/docker/daemon.json"
    if [[ -f "$DAEMON_JSON" ]]; then
        cp "$DAEMON_JSON" "$DAEMON_JSON.bak"
    fi

    echo -n "{" > "$DAEMON_JSON"
    for mirror in "${MIRRORS[@]}"; do
        echo -n "\"registry-mirrors\": [\"https://$mirror\"]," >> "$DAEMON_JSON"
    done
    echo -e "\n\"insecure-registries\": []\n}" >> "$DAEMON_JSON"

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

exit 0