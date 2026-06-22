#!/usr/bin/env bash
set -e

echo "Running docker-compose validation tests..."
ERRORS=0

# Mock env vars needed for compose config
export DOMAIN=example.com
export AUTHENTIK_DOMAIN=auth.example.com
export AUTHENTIK_POSTGRES_PASSWORD=mock
export AUTHENTIK_REDIS_PASSWORD=mock
export AUTHENTIK_SECRET_KEY=mock
export GRAFANA_ADMIN_PASSWORD=mock
export GRAFANA_OAUTH_CLIENT_ID=mock
export GRAFANA_OAUTH_CLIENT_SECRET=mock
export CF_DNS_API_TOKEN=mock
export CF_ZONE_API_TOKEN=mock
export CF_ZONE_ID=mock
export ACME_EMAIL=test@example.com

# Base infrastructure
if ! docker compose -f docker-compose.base.yml config -q; then
    echo "❌ Validation failed for docker-compose.base.yml"
    ERRORS=$((ERRORS+1))
else
    echo "✅ Validation passed for docker-compose.base.yml"
fi

# All stacks
for stack in stacks/*; do
    if [ -d "$stack" ] && [ -f "$stack/docker-compose.yml" ]; then
        if ! docker compose -f "$stack/docker-compose.yml" config -q >/dev/null 2>&1; then
            echo "❌ Validation failed for $stack/docker-compose.yml"
            ERRORS=$((ERRORS+1))
        else
            echo "✅ Validation passed for $stack/docker-compose.yml"
        fi
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo "Failed compose tests: $ERRORS"
    exit 1
fi

echo "All compose files are valid!"
