#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
exec "$BASE_DIR/tests/run-tests.sh" --all "$@"
