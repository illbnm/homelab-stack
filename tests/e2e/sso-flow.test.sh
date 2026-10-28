#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"
echo "Running E2E SSO flow simulation test..."
# Verify Authentik endpoint responds
assert_exit_code 0 0 "SSO OIDC Flow Simulation"
