#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Secret Generator
# =============================================================================
# Generates random passwords for all required environment variables.
# Reads .env.example and fills in empty values with secure random strings.
#
# Usage:
#   ./scripts/generate-secrets.sh              # Generate to .env
#   ./scripts/generate-secrets.sh --stdout     # Print to stdout
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
ENV_FILE="${PROJECT_ROOT}/.env"
TO_STDOUT=false

if [[ "${1:-}" == "--stdout" ]]; then
  TO_STDOUT=true
fi

# ---------------------------------------------------------------------------
# Random password generator (pure bash fallback if openssl unavailable)
# ---------------------------------------------------------------------------
generate_password() {
  local length="${1:-32}"

  if command -v openssl &>/dev/null; then
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "${length}"
  elif [[ -f /dev/urandom ]]; then
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${length}"
  else
    # Fallback: use $RANDOM (less secure, but works everywhere)
    local result=""
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for _ in $(seq 1 "${length}"); do
      result="${result}${chars:RANDOM%${#chars}:1}"
    done
    echo "${result}"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ ! -f "${ENV_EXAMPLE}" ]]; then
  echo "[ERROR] .env.example not found at ${ENV_EXAMPLE}" >&2
  exit 1
fi

OUTPUT=""

while IFS= read -r line; do
  # Preserve comments and blank lines
  if [[ "${line}" =~ ^#.*$ ]] || [[ -z "${line}" ]]; then
    OUTPUT="${OUTPUT}${line}\n"
    continue
  fi

  # Parse KEY=VALUE lines
  if [[ "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"

    # If value is empty, generate a random password
    if [[ -z "${value}" ]]; then
      case "${key}" in
        *EMAIL*)
          value="admin@homelab.local"
          ;;
        *USER*)
          value="admin"
          ;;
        DOMAIN)
          value="homelab.local"
          ;;
        TZ)
          value="UTC"
          ;;
        BACKUP_DIR)
          value="/opt/homelab/backups/databases"
          ;;
        BACKUP_RETENTION_DAYS)
          value="7"
          ;;
        *)
          value="$(generate_password 32)"
          ;;
      esac
    fi

    OUTPUT="${OUTPUT}${key}=${value}\n"
  else
    OUTPUT="${OUTPUT}${line}\n"
  fi
done < "${ENV_EXAMPLE}"

if [[ "${TO_STDOUT}" == true ]]; then
  echo -e "${OUTPUT}"
else
  echo -e "${OUTPUT}" > "${ENV_FILE}"
  echo "[INFO] Generated secrets written to ${ENV_FILE}"
  echo "[INFO] Review and customize values as needed."
fi
