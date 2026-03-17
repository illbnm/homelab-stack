#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Backup Wrapper
# =============================================================================
# Convenience wrapper that sources .env and runs the backup script.
#
# Usage:
#   ./scripts/backup-databases.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source .env if available
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
fi

# Delegate to the actual backup script
exec bash "${PROJECT_ROOT}/stacks/databases/scripts/backup-databases.sh"
