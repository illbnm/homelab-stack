#!/bin/bash

read -p "Are you in China? (y/n): " in_china

if [[ "$in_china" == "y" ]]; then
    mirrors=("mirror.gcr.io" "docker.m.daocloud.io" "hub-mirror.c.163.com" "mirror.baidubce.com")
    echo "Select a Docker mirror:"
    select mirror in "${mirrors[@]}"; do
        case $mirror in
            "mirror.gcr.io"|"docker.m.daocloud.io"|"hub-mirror.c.163.com"|"mirror.baidubce.com")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done

    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    fi

    echo "{\"registry-mirrors\": [\"https://$mirror\"]}" > /etc/docker/daemon.json

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