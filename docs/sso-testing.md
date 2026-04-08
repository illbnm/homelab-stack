# SSO Testing Guide - Authentik Integration

Comprehensive testing procedures for validating SSO integration with all HomeLab services.

## Table of Contents

1. [Pre-Test Checklist](#pre-test-checklist)
2. [Automated Testing](#automated-testing)
3. [Manual Testing Procedures](#manual-testing-procedures)
4. [Performance Testing](#performance-testing)
5. [Security Testing](#security-testing)
6. [Integration Testing Matrix](#integration-testing-matrix)
7. [Test Results Template](#test-results-template)

---

## Pre-Test Checklist

Before beginning testing, verify all prerequisites are met.

### Infrastructure Checks

```bash
# 1. All containers running and healthy
docker compose -f stacks/sso/docker-compose.yml ps

# Expected output: All services show "healthy"
# - authentik-postgres (healthy)
# - authentik-redis (healthy)
# - authentik-server (healthy)
# - authentik-worker (healthy)

# 2. Traefik is running
docker compose -f stacks/base/docker-compose.yml ps traefik

# 3. Network connectivity
docker network inspect proxy | grep -A 10 "Containers"

# 4. DNS resolution
nslookup auth.${DOMAIN}
nslookup grafana.${DOMAIN}
nslookup git.${DOMAIN}

# 5. Certificates issued
docker exec traefik cat /acme.json | jq -r '.letsencrypt.Certificates[].domain.main'
```

### Configuration Validation

```bash
# 1. Environment variables set
cd stacks/sso
grep -E "AUTHENTIK_SECRET_KEY|AUTHENTIK_POSTGRES_PASSWORD|AUTHENTIK_REDIS_PASSWORD|AUTHENTIK_BOOTSTRAP_TOKEN" .env

# 2. OAuth client IDs generated
grep -E "OAUTH_CLIENT_ID|OAUTH_CLIENT_SECRET" ../../.env

# 3. Authentik is accessible
curl -f https://auth.${DOMAIN}/-/health/ready/ && echo "✅ Authentik healthy"

# 4. OIDC providers created
./scripts/authentik-setup.sh --dry-run
```

### User Accounts Prepared

Create test users for each access level:

```bash
# Via Authentik UI or API
# 1. Admin user (in homelab-admins group)
# 2. Regular user (in homelab-users group)
# 3. Media user (in media-users group)
# 4. Test user with no groups
```

---

## Automated Testing

### Test Script

Create a comprehensive test script:

```bash
#!/bin/bash
# scripts/test-sso.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

PASS=0
FAIL=0

test_pass() {
  echo -e "${GREEN}✓ PASS${RESET}: $1"
  ((PASS++))
}

test_fail() {
  echo -e "${RED}✗ FAIL${RESET}: $1"
  ((FAIL++))
}

test_skip() {
  echo -e "${YELLOW}⊘ SKIP${RESET}: $1"
}

# Test 1: Authentik Health
test_authentik_health() {
  echo "=== Testing Authentik Health ==="
  
  if curl -sf "https://auth.${DOMAIN}/-/health/ready/" > /dev/null; then
    test_pass "Authentik health endpoint"
  else
    test_fail "Authentik health endpoint"
  fi
  
  if curl -sf "https://auth.${DOMAIN}/-/health/live/" > /dev/null; then
    test_pass "Authentik liveness endpoint"
  else
    test_fail "Authentik liveness endpoint"
  fi
}

# Test 2: OIDC Discovery Endpoints
test_oidc_discovery() {
  echo "=== Testing OIDC Discovery Endpoints ==="
  
  local services=("grafana" "gitea" "outline" "open-webui" "nextcloud")
  
  for service in "${services[@]}"; do
    if curl -sf "https://auth.${DOMAIN}/application/o/${service}/.well-known/openid-configuration" | jq -e '.issuer' > /dev/null; then
      test_pass "OIDC discovery for ${service}"
    else
      test_fail "OIDC discovery for ${service}"
    fi
  done
}

# Test 3: ForwardAuth Middleware
test_forwardauth() {
  echo "=== Testing ForwardAuth Middleware ==="
  
  # Test protected endpoint returns 401 without auth
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" "https://prometheus.${DOMAIN}/")
  
  if [ "$response" = "302" ] || [ "$response" = "401" ]; then
    test_pass "Prometheus protected by ForwardAuth (status: $response)"
  else
    test_fail "Prometheus not properly protected (status: $response)"
  fi
}

# Test 4: Service Accessibility (with auth)
test_service_access() {
  echo "=== Testing Service Accessibility ==="
  
  # These should redirect to Authentik
  local services=(
    "grafana.${DOMAIN}"
    "git.${DOMAIN}"
    "docs.${DOMAIN}"
    "ai.${DOMAIN}"
    "nextcloud.${DOMAIN}"
  )
  
  for service in "${services[@]}"; do
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" -L "https://${service}")
    
    if [ "$response" = "200" ] || [ "$response" = "302" ]; then
      test_pass "Service accessible: ${service}"
    else
      test_fail "Service not accessible: ${service} (status: $response)"
    fi
  done
}

# Test 5: Database Connectivity
test_database() {
  echo "=== Testing Database Connectivity ==="
  
  if docker exec authentik-postgres pg_isready -U authentik > /dev/null 2>&1; then
    test_pass "PostgreSQL connectivity"
  else
    test_fail "PostgreSQL connectivity"
  fi
  
  if docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD}" ping | grep -q "PONG"; then
    test_pass "Redis connectivity"
  else
    test_fail "Redis connectivity"
  fi
}

# Test 6: Container Health
test_container_health() {
  echo "=== Testing Container Health Status ==="
  
  local containers=("authentik-server" "authentik-worker" "authentik-postgres" "authentik-redis")
  
  for container in "${containers[@]}"; do
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [ "$status" = "healthy" ]; then
      test_pass "Container ${container} is healthy"
    else
      test_fail "Container ${container} is ${status}"
    fi
  done
}

# Run all tests
main() {
  echo "Starting SSO Integration Tests..."
  echo "Domain: ${DOMAIN}"
  echo "Authentik: https://auth.${DOMAIN}"
  echo ""
  
  test_container_health
  test_database
  test_authentik_health
  test_oidc_discovery
  test_forwardauth
  test_service_access
  
  echo ""
  echo "==================================="
  echo "Test Results: ${PASS} passed, ${FAIL} failed"
  echo "==================================="
  
  if [ $FAIL -gt 0 ]; then
    exit 1
  fi
}

main "$@"
```

### Run Automated Tests

```bash
# Make executable
chmod +x scripts/test-sso.sh

# Run tests
./scripts/test-sso.sh

# Save results
./scripts/test-sso.sh | tee test-results-$(date +%Y%m%d-%H%M%S).log
```

---

## Manual Testing Procedures

### Test 1: Authentik Admin UI Access

**Objective:** Verify admin can access Authentik admin interface

**Steps:**

1. Open browser in incognito/private mode
2. Navigate to `https://auth.${DOMAIN}/if/admin/`
3. Login with admin credentials from `.env`
4. Verify dashboard loads successfully

**Expected Results:**
- ✅ Login page appears
- ✅ Admin credentials work
- ✅ Dashboard shows system status
- ✅ No error messages

**Status:** ☐ PASS ☐ FAIL

**Notes:**
```
[Record any issues or observations]
```

---

### Test 2: User Registration and Login

**Objective:** Test user authentication flow

**Pre-conditions:**
- Test user account created in Authentik

**Steps:**

1. Navigate to `https://auth.${DOMAIN}/`
2. Click "Sign in"
3. Enter test user credentials
4. Verify user dashboard loads

**Expected Results:**
- ✅ Login form accepts credentials
- ✅ User redirected to dashboard
- ✅ User information displayed correctly
- ✅ Available applications shown

**Status:** ☐ PASS ☐ FAIL

---

### Test 3: Grafana SSO Integration

**Objective:** Verify Grafana uses Authentik for authentication

**Steps:**

1. Navigate to `https://grafana.${DOMAIN}`
2. Click "Sign in with Authentik" button
3. Complete Authentik login
4. Verify redirected back to Grafana
5. Check user profile shows correct name/email
6. Verify role matches group membership

**Test Cases:**

| User Group | Expected Role | Test User | Result |
|-----------|---------------|-----------|--------|
| Grafana Admins | Admin | | ☐ PASS ☐ FAIL |
| Grafana Editors | Editor | | ☐ PASS ☐ FAIL |
| No group | Viewer | | ☐ PASS ☐ FAIL |

**Expected Results:**
- ✅ Authentik button appears on login page
- ✅ Redirect to Authentik works
- ✅ Redirect back to Grafana works
- ✅ User account created automatically
- ✅ Role assigned based on group
- ✅ Email and name populated correctly

**Status:** ☐ PASS ☐ FAIL

**Notes:**
```
[Test each role and record results]
```

---

### Test 4: Gitea SSO Integration

**Objective:** Verify Gitea uses Authentik for authentication

**Steps:**

1. Navigate to `https://git.${DOMAIN}`
2. Click "Sign in with OpenID" or Authentik button
3. Complete Authentik login
4. Verify redirected back to Gitea
5. Check user profile
6. Verify avatar is synced

**Expected Results:**
- ✅ Authentik option visible on login
- ✅ Login flow completes successfully
- ✅ User account created automatically
- ✅ Email matches Authentik email
- ✅ Avatar synced from Authentik
- ✅ Can create repositories

**Status:** ☐ PASS ☐ FAIL

**Notes:**
```
[Record any issues with account linking or avatar sync]
```

---

### Test 5: Outline SSO Integration

**Objective:** Verify Outline uses Authentik for authentication

**Steps:**

1. Navigate to `https://docs.${DOMAIN}`
2. Click "Continue with Authentik"
3. Complete Authentik login
4. Verify redirected back to Outline
5. Create a test document
6. Verify document saves successfully

**Expected Results:**
- ✅ Authentik button visible
- ✅ SSO flow completes
- ✅ User account created
- ✅ Can access documents
- ✅ Can create new documents
- ✅ User permissions work correctly

**Status:** ☐ PASS ☐ FAIL

---

### Test 6: Open WebUI SSO Integration

**Objective:** Verify Open WebUI uses Authentik for authentication

**Steps:**

1. Navigate to `https://ai.${DOMAIN}`
2. Click "Sign in with Authentik"
3. Complete Authentik login
4. Verify redirected back to Open WebUI
5. Send a test message to AI
6. Verify conversation saves

**Expected Results:**
- ✅ Authentik button visible
- ✅ SSO flow completes
- ✅ User account created
- ✅ Email-based merging works
- ✅ Can access AI features
- ✅ Conversations persist

**Status:** ☐ PASS ☐ FAIL

---

### Test 7: Nextcloud SSO Integration

**Objective:** Verify Nextcloud uses Authentik via Social Login

**Pre-conditions:**
- Social Login app installed
- OIDC provider configured

**Steps:**

1. Navigate to `https://nextcloud.${DOMAIN}`
2. Click "Login with Authentik"
3. Complete Authentik login
4. Verify redirected back to Nextcloud
5. Upload a test file
6. Verify file appears in file list

**Expected Results:**
- ✅ Authentik button visible on login
- ✅ SSO flow completes
- ✅ User account created
- ✅ Can access files
- ✅ Can upload files
- ✅ User quota set correctly

**Status:** ☐ PASS ☐ FAIL

---

### Test 8: Portainer ForwardAuth Protection

**Objective:** Verify Portainer is protected by ForwardAuth

**Steps:**

1. Navigate to `https://portainer.${DOMAIN}`
2. Verify redirect to Authentik occurs
3. Complete Authentik login
4. Verify redirected back to Portainer
5. Logout from Authentik
6. Try accessing Portainer again

**Expected Results:**
- ✅ Unauthenticated access redirects to Authentik
- ✅ After login, Portainer accessible
- ✅ No duplicate login required
- ✅ Session persists across refresh
- ✅ Logout requires re-authentication

**Status:** ☐ PASS ☐ FAIL

---

### Test 9: Prometheus ForwardAuth Protection

**Objective:** Verify Prometheus is protected by ForwardAuth

**Steps:**

1. Navigate to `https://prometheus.${DOMAIN}`
2. Verify redirect to Authentik occurs
3. Complete Authentik login
4. Verify redirected back to Prometheus
5. Run a test query
6. Logout and verify access denied

**Expected Results:**
- ✅ Unauthenticated access denied
- ✅ After login, Prometheus accessible
- ✅ Can execute queries
- ✅ UI loads correctly
- ✅ Logout blocks access

**Status:** ☐ PASS ☐ FAIL

---

### Test 10: Cross-Service Single Sign-On

**Objective:** Verify SSO works across multiple services

**Steps:**

1. Login to Authentik at `https://auth.${DOMAIN}`
2. Open new tab: Navigate to `https://grafana.${DOMAIN}`
3. Verify automatic login (no redirect)
4. Open new tab: Navigate to `https://git.${DOMAIN}`
5. Verify automatic login
6. Open new tab: Navigate to `https://docs.${DOMAIN}`
7. Verify automatic login

**Expected Results:**
- ✅ Login to Authentik establishes session
- ✅ Grafana auto-login works
- ✅ Gitea auto-login works
- ✅ Outline auto-login works
- ✅ No additional authentication required
- ✅ Session shared across services

**Status:** ☐ PASS ☐ FAIL

---

### Test 11: Group-Based Access Control

**Objective:** Verify group membership controls access

**Test Matrix:**

| Test User | Groups | Expected Access | Actual Access | Status |
|-----------|--------|-----------------|---------------|--------|
| admin_user | homelab-admins | All services | | ☐ |
| regular_user | homelab-users | Standard services | | ☐ |
| media_user | media-users | Media only | | ☐ |
| no_group_user | (none) | Minimal access | | ☐ |

**Steps:**

1. Create test users in Authentik with different group memberships
2. Login as each user
3. Attempt to access various services
4. Verify access matches group permissions

**Expected Results:**
- ✅ Admin users can access all services
- ✅ Regular users blocked from admin panels
- ✅ Media users can only access media services
- ✅ Users without groups have minimal access

**Status:** ☐ PASS ☐ FAIL

---

### Test 12: Logout and Session Management

**Objective:** Verify logout works across all services

**Steps:**

1. Login to Authentik
2. Access multiple services (Grafana, Gitea, Outline)
3. Logout from Authentik
4. Try to access services again
5. Verify all require re-authentication

**Expected Results:**
- ✅ Logout from Authentik terminates session
- ✅ All services require re-authentication
- ✅ No lingering sessions
- ✅ Browser back button doesn't restore access

**Status:** ☐ PASS ☐ FAIL

---

## Performance Testing

### Test 1: Login Performance

**Objective:** Measure authentication latency

**Steps:**

```bash
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Test Authentik login endpoint
hey -n 100 -c 10 -m POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=${AUTHENTIK_ADMIN_PASSWORD}" \
  https://auth.${DOMAIN}/api/v3/flows/executor/default-authentication-flow/
```

**Metrics to Record:**

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Average Response Time | < 500ms | | ☐ |
| 95th Percentile | < 1000ms | | ☐ |
| Throughput (req/s) | > 50 | | ☐ |
| Error Rate | < 1% | | ☐ |

---

### Test 2: OIDC Token Issuance

**Objective:** Measure OIDC token issuance performance

**Steps:**

```bash
# Get token for Grafana
time curl -X POST "https://auth.${DOMAIN}/application/o/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${GRAFANA_OAUTH_CLIENT_ID}" \
  -d "client_secret=${GRAFANA_OAUTH_CLIENT_SECRET}" \
  -d "scope=openid profile email"
```

**Metrics:**

| Service | Token Issue Time | Status |
|---------|------------------|--------|
| Grafana | | ☐ |
| Gitea | | ☐ |
| Outline | | ☐ |
| Open WebUI | | ☐ |
| Nextcloud | | ☐ |

**Target:** < 200ms per token issuance

---

### Test 3: Concurrent User Sessions

**Objective:** Test performance with multiple concurrent users

**Steps:**

```bash
# Create test users script
cat > /tmp/create_test_users.sh << 'EOF'
#!/bin/bash
for i in {1..50}; do
  curl -X POST "https://auth.${DOMAIN}/api/v3/core/users/" \
    -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"testuser${i}\",\"name\":\"Test User ${i}\",\"email\":\"test${i}@example.com\",\"password\":\"TestPass${i}!\"}"
done
EOF

# Run concurrent login test
for i in {1..50}; do
  curl -X POST "https://auth.${DOMAIN}/api/v3/flows/executor/default-authentication-flow/" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=testuser${i}&password=TestPass${i}!" &
done
wait
```

**Metrics:**

| Concurrent Users | Response Time | Error Rate | Status |
|------------------|---------------|------------|--------|
| 10 | | | ☐ |
| 25 | | | ☐ |
| 50 | | | ☐ |
| 100 | | | ☐ |

---

## Security Testing

### Test 1: Session Security

**Objective:** Verify session tokens are secure

**Steps:**

1. Login to Authentik
2. Open browser developer tools
3. Inspect cookies for Authentik domain
4. Verify:
   - [ ] Cookies use `Secure` flag
   - [ ] Cookies use `HttpOnly` flag
   - [ ] SameSite policy is set
   - [ ] Session tokens are not exposed in URL

**Status:** ☐ PASS ☐ FAIL

---

### Test 2: CSRF Protection

**Objective:** Verify CSRF tokens are used

**Steps:**

1. Open browser developer tools
2. Login to Authentik
3. Monitor network requests
4. Verify:
   - [ ] POST requests include CSRF token
   - [ ] CSRF tokens are validated
   - [ ] Invalid tokens are rejected

**Status:** ☐ PASS ☐ FAIL

---

### Test 3: SQL Injection Protection

**Objective:** Verify Authentik is protected against SQL injection

**Steps:**

1. Attempt login with SQL injection payloads:
   - Username: `admin' OR '1'='1`
   - Username: `admin'; DROP TABLE users; --`
2. Verify login fails gracefully
3. Check logs for errors

**Expected Results:**
- ✅ SQL injection attempts fail
- ✅ No database errors leaked
- ✅ Normal error message shown
- ✅ No data exposed

**Status:** ☐ PASS ☐ FAIL

---

### Test 4: Brute Force Protection

**Objective:** Verify rate limiting is active

**Steps:**

1. Attempt login with wrong password 10 times
2. Verify:
   - [ ] Account gets temporarily locked
   - [ ] Error message indicates lockout
   - [ ] Subsequent attempts blocked
   - [ ] Lockout expires after configured time

**Status:** ☐ PASS ☐ FAIL

---

### Test 5: Token Expiration

**Objective:** Verify tokens expire correctly

**Steps:**

1. Login to Authentik
2. Get access token
3. Wait for token expiration (default: 5 minutes)
4. Attempt to use expired token
5. Verify:
   - [ ] Expired token is rejected
   - [ ] User must re-authenticate
   - [ ] Refresh token flow works (if applicable)

**Status:** ☐ PASS ☐ FAIL

---

## Integration Testing Matrix

Complete matrix of all service integration tests:

| Service | Integration Type | Health Check | OIDC Flow | Role Mapping | Auto-Provision | Status |
|---------|------------------|--------------|-----------|--------------|----------------|--------|
| Authentik | - | ☐ | - | - | - | |
| Grafana | Native OIDC | ☐ | ☐ | ☐ | ☐ | |
| Gitea | Native OIDC | ☐ | ☐ | N/A | ☐ | |
| Outline | Native OIDC | ☐ | ☐ | N/A | ☐ | |
| Open WebUI | Native OIDC | ☐ | ☐ | N/A | ☐ | |
| Nextcloud | Social Login | ☐ | ☐ | ☐ | ☐ | |
| Portainer | ForwardAuth | ☐ | ☐ | N/A | N/A | |
| Prometheus | ForwardAuth | ☐ | ☐ | N/A | N/A | |

---

## Test Results Template

Use this template to document test results:

```markdown
# SSO Integration Test Results

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Environment:** [Production/Staging/Development]
**Domain:** ${DOMAIN}

## Summary

- Total Tests: X
- Passed: X
- Failed: X
- Skipped: X

## Automated Tests

[Paste output from test-sso.sh]

## Manual Test Results

### Authentik Admin UI
- Status: ☐ PASS ☐ FAIL
- Notes: 

### Grafana Integration
- Status: ☐ PASS ☐ FAIL
- Role Mapping: ☐ PASS ☐ FAIL
- Notes:

### Gitea Integration
- Status: ☐ PASS ☐ FAIL
- Avatar Sync: ☐ PASS ☐ FAIL
- Notes:

[Continue for all services...]

## Performance Test Results

| Test | Target | Actual | Status |
|------|--------|--------|--------|
| Login Latency | < 500ms | | |
| Token Issuance | < 200ms | | |
| Concurrent Users (50) | < 1s | | |

## Security Test Results

- Session Security: ☐ PASS ☐ FAIL
- CSRF Protection: ☐ PASS ☐ FAIL
- SQL Injection: ☐ PASS ☐ FAIL
- Brute Force Protection: ☐ PASS ☐ FAIL
- Token Expiration: ☐ PASS ☐ FAIL

## Issues Found

1. [Description of issue]
   - Severity: High/Medium/Low
   - Steps to reproduce:
   - Proposed fix:

2. [Another issue...]

## Recommendations

- [Recommendation 1]
- [Recommendation 2]

## Sign-off

- [ ] All critical tests passed
- [ ] No high-severity issues
- [ ] Performance meets requirements
- [ ] Security requirements met

**Approved by:** [Name]
**Date:** YYYY-MM-DD
```

---

## Troubleshooting Failed Tests

### Common Failures

| Test | Common Failure | Solution |
|------|----------------|----------|
| Authentik Health | Container not healthy | Check logs: `docker logs authentik-server` |
| OIDC Discovery | 404 on .well-known | Re-run setup script |
| ForwardAuth | Redirect loop | Check middleware config in authentik.yml |
| Service Access | Certificate error | Verify Traefik ACME certs |
| Role Mapping | All users get Viewer | Check group names match exactly |
| Session Security | Missing Secure flag | Update Authentik config |

### Debug Commands

```bash
# Check Authentik logs
docker compose -f stacks/sso/docker-compose.yml logs -f authentik-server

# Check Traefik access logs
docker compose -f stacks/base/docker-compose.yml logs -f traefik | grep authentik

# Inspect OIDC provider
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  https://auth.${DOMAIN}/api/v3/providers/oauth2/

# Test database queries
docker exec -it authentik-postgres psql -U authentik -c "SELECT * FROM authentik_core_user;"

# Verify Redis cache
docker exec -it authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD}" keys "*"
```

---

*Last updated: 2025-01-08*
