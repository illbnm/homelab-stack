#!/bin/bash
set -euo pipefail

# Static Analysis: Validate Dynaconf nested keys in .env
log() { echo "[VERIFY] $1"; }

log "Running static analysis on .env..."
if ! grep -q "__" .env; then
    log "ERROR: .env missing double-underscore (__) nested key convention required for production-grade config."
    exit 1
fi

# Dynamic Analysis: OIDC Discovery and JWKS
log "Verifying OIDC Discovery endpoint..."
OIDC_CONFIG_URL="https://${AUTHENTIK_DOMAIN}/application/o/authentik/"

RESPONSE=$(curl -s -L "${OIDC_CONFIG_URL}.well-known/openid-configuration")
if [[ -z "$RESPONSE" ]]; then
    log "ERROR: Could not reach .well-known/openid-configuration"
    exit 1
fi

ISSUER=$(echo "$RESPONSE" | jq -r '.issuer')
JWKS_URI=$(echo "$RESPONSE" | jq -r '.jwks_uri')

if [[ "$ISSUER" != "https://${AUTHENTIK_DOMAIN}/" ]]; then
    log "ERROR: Issuer mismatch. Expected https://${AUTHENTIK_DOMAIN}/, got $ISSUER"
    exit 1
fi

if ! curl -s -f "$JWKS_URI" > /dev/null; then
    log "ERROR: JWKS endpoint is inaccessible."
    exit 1
fi

# Connectivity Check: Docker API health
log "Checking container health..."
for service in authentik-server authentik-worker; do
    STATE=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unhealthy")
    if [[ "$STATE" != "healthy" ]]; then
        log "ERROR: Service $service is $STATE"
        exit 1
    fi
done

log "SSO Stack verification PASSED."
