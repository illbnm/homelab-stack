#!/bin/bash

echo "Are you in China? (y/n)"
read -r in_china

if [[ "$in_china" == "y" ]]; then
    MIRRORS=("mirror.gcr.io" "docker.m.daocloud.io" "hub-mirror.c.163.com" "mirror.baidubce.com")
    DAEMON_JSON="/etc/docker/daemon.json"

    if [[ -f "$DAEMON_JSON" ]]; then
        cp "$DAEMON_JSON" "$DAEMON_JSON.bak"
    fi

    echo "{
        \"registry-mirrors\": ["
    for mirror in "${MIRRORS[@]}"; do
        echo "            \"https://$mirror\","
    done
    echo "        ]
    }" > "$DAEMON_JSON"

    systemctl restart docker

    echo "Testing Docker pull with hello-world..."
    if docker pull hello-world; then
        echo "Docker pull successful!"
    else
        echo "Docker pull failed. Please check your configuration."
    fi
else
    echo "No changes made. Not in China."
fi