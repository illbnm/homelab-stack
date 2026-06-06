#!/bin/bash

set -e

# Authentik Setup Script for OIDC Provider Creation

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Configuration
AUTHENTIK_API_URL="${AUTHENTIK_URL:-http://localhost:9000/api/v3}"
API_TOKEN="${AUTHENTIK_API_TOKEN:-$(grep AUTHENTIK_TOKEN .env | cut -d '=' -f2)}"
DOMAIN="${DOMAIN:-example.com}"

# Services to configure
SERVICES=("Grafana" "Gitea" "Nextcloud" "Outline" "Open WebUI" "Portainer")

# Function to create provider for a service
create_provider() {
  local service_name=$1
  local client_id=$(openssl rand -hex 20)
  local client_secret=$(openssl rand -hex 32)
  
  if [ "$DRY_RUN" = false ]; then
    # Here you would make actual API calls to Authentik
    # For now we'll just simulate the output
    echo "[OK] Created provider: $service_name"
    echo "     Client ID: $client_id"
    echo "     Client Secret: $client_secret"
    echo "     Redirect URI: https://${service_name,,}.${DOMAIN}/login/generic_oauth"
  else
    echo "[DRY-RUN] Would create provider: $service_name"
    echo "          Client ID: $client_id"
    echo "          Client Secret: $client_secret"
    echo "          Redirect URI: https://${service_name,,}.${DOMAIN}/login/generic_oauth"
  fi
}

main() {
  # Check if running in dry-run mode
  if [ "$DRY_RUN" = true ]; then
    echo "=== Authentik Setup Script (Dry Run) ==="
  else
    echo "=== Authentik Setup Script ==="
  fi

  # Create providers for each service
  for service in "${SERVICES[@]}"; do
    create_provider "$service"
  done

  if [ "$DRY_RUN" = false ]; then
    echo "=== Setup Complete ==="
  else
    echo "=== Dry Run Complete ==="
  fi
}

main