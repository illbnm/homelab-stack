#!/usr/bin/env bash
# Compatibility wrapper. The canonical setup entrypoint is authentik-setup.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/authentik-setup.sh" "$@"
