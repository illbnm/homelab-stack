#!/usr/bin/env bash
# scripts/localize-images.sh
# Replaces international container registries with domestic mirrors

set -euo pipefail

MODE="${1:---check}"

case "$MODE" in
    --cn)
        echo "[*] Localizing images to CN mirrors..."
        find stacks -name 'docker-compose.yml' -exec sed -i 's|ghcr.io/|m.daocloud.io/ghcr.io/|g' {} +
        find stacks -name 'docker-compose.yml' -exec sed -i 's|gcr.io/|m.daocloud.io/gcr.io/|g' {} +
        echo "[+] Successfully localized compose image definitions."
        ;;
    --restore)
        echo "[*] Restoring original registry prefixes..."
        find stacks -name 'docker-compose.yml' -exec sed -i 's|m.daocloud.io/ghcr.io/|ghcr.io/|g' {} +
        find stacks -name 'docker-compose.yml' -exec sed -i 's|m.daocloud.io/gcr.io/|gcr.io/|g' {} +
        echo "[+] Restored original registry references."
        ;;
    --dry-run)
        echo "[*] DRY RUN: Scanning for gcr.io/ghcr.io images..."
        grep -rn "image:.*ghcr.io" stacks/ || true
        grep -rn "image:.*gcr.io" stacks/ || true
        ;;
    --check|check)
        echo "[*] Checking registry distribution:"
        count=$(grep -rnE "(ghcr.io|gcr.io)" stacks/ | wc -l || echo 0)
        echo "Found $count international image references."
        ;;
    *)
        echo "Usage: $0 [--cn | --restore | --dry-run | --check]"
        exit 1
        ;;
esac
