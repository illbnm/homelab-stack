#!/usr/bin/env bash
# scripts/check-connectivity.sh
# Tests network latency and accessibility to core registries

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Network & Registry Connectivity Benchmark           ║"
echo "╚══════════════════════════════════════════════════════════════╝"

test_target() {
    local name="$1"
    local url="$2"
    if curl --connect-timeout 3 -m 5 -sfI "$url" >/dev/null 2>&1; then
        echo -e "[OK]   $name — reachable"
    else
        echo -e "[WARN] $name — unreachable or slow; recommended to activate CN mirrors"
    fi
}

test_target "Docker Hub" "https://hub.docker.com"
test_target "GitHub" "https://github.com"
test_target "Google Container Registry" "https://gcr.io"
test_target "GitHub Container Registry" "https://ghcr.io"
test_target "Cloudflare DNS" "https://1.1.1.1"

echo -e "\n[✓] Diagnostic connectivity check completed."
