#!/usr/bin/env bash
# Localize images in Docker Compose files
set -e

MODE="${1:---check}"

if [ "$MODE" = "--check" ]; then
    echo "Checking for external gcr.io / ghcr.io images..."
    grep -rn "gcr.io/" stacks/ || echo "[OK] No gcr.io references found."
elif [ "$MODE" = "--cn" ]; then
    echo "Replacing gcr.io/ghcr.io with mirror endpoints..."
    find stacks/ -name "docker-compose.yml" -exec sed -i.bak 's|ghcr.io/|m.daocloud.io/ghcr.io/|g' {} +
    find stacks/ -name "docker-compose.yml" -exec sed -i.bak 's|gcr.io/|m.daocloud.io/gcr.io/|g' {} +
    echo "[OK] Images localized."
elif [ "$MODE" = "--restore" ]; then
    echo "Restoring original image sources..."
    find stacks/ -name "docker-compose.yml.bak" | while read -r f; do
        mv "$f" "${f%.bak}"
    done
    echo "[OK] Images restored."
fi
