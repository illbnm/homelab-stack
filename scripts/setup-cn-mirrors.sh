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

    echo "{" > "$DAEMON_JSON"
    echo '  "registry-mirrors": [' >> "$DAEMON_JSON"
    for mirror in "${MIRRORS[@]}"; do
        echo "    \"https://$mirror/\"," >> "$DAEMON_JSON"
    done
    echo "  ]" >> "$DAEMON_JSON"
    echo "}" >> "$DAEMON_JSON"

    systemctl restart docker

    echo "Testing Docker pull..."
    if docker pull hello-world; then
        echo "Docker pull successful!"
    else
        echo "Docker pull failed. Please check your configuration."
        exit 1
    fi
else
    echo "Skipping Docker mirror setup."
fi

exit 0