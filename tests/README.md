# HomeLab Stack — Test Suite

This directory contains automated test scripts for verifying the HomeLab Stack deployment.

## Available Tests

### test-sso-integration.sh

Comprehensive SSO integration test suite that verifies:

- Authentik core services health
- OIDC provider configuration
- Grafana SSO integration
- Gitea SSO integration
- Outline SSO integration
- Open WebUI SSO integration
- ForwardAuth middleware configuration
- User groups setup

**Usage:**

```bash
cd /path/to/homelab-stack
./tests/test-sso-integration.sh
```

**Requirements:**

- Docker and docker compose installed
- All stacks running (base, sso, productivity, ai, monitoring)
- `.env` file configured with all required variables
- `curl` and `jq` installed

**Test Output:**

```
========================================
  HomeLab SSO Integration Test Suite
========================================

[INFO] Starting SSO integration tests...
[INFO] Domain: example.com
[INFO] Authentik Domain: auth.example.com

[TEST] Authentik Core Services
[INFO] Checking Authentik Server health...
✅ Authentik Server is healthy
...

========================================
  Test Summary
========================================

✅ Tests Passed:  35
❌ Tests Failed:  0
⚠️  Tests Skipped: 0

Pass Rate: 100%

All tests passed! SSO integration is working correctly.
```

## Running All Tests

```bash
# Run SSO integration tests
./tests/test-sso-integration.sh

# Run with verbose output
VERBOSE=1 ./tests/test-sso-integration.sh
```

## Test Coverage

| Component | Tests | Description |
|-----------|-------|-------------|
| Authentik Core | 6 | Server, Worker, DB, Redis, UI accessibility |
| OIDC Providers | 7 | Client credentials configuration |
| Grafana | 3 | Health, UI, OAuth config |
| Gitea | 3 | Health, UI, OAuth config |
| Outline | 2 | Health, UI |
| Open WebUI | 3 | Health, UI, OAuth config |
| ForwardAuth | 2 | Middleware configuration |
| User Groups | 2 | Setup script, group definitions |
| **Total** | **28** | |

## Adding New Tests

To add new tests, create a new test function in `test-sso-integration.sh`:

```bash
test_new_service() {
  log_test "New Service Integration"
  
  log_info "Checking New Service health..."
  if check_container_healthy "new-service"; then
    log_info "✅ New Service is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ New Service is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
```

Then call the function in the `main()` function:

```bash
test_new_service
```

## Troubleshooting

### Test Fails: Container Not Healthy

**Cause:** Container is still starting or crashed

**Solution:**

```bash
# Check container logs
docker logs <container-name>

# Check container status
docker ps -a | grep <container-name>

# Restart container
docker compose restart <service-name>
```

### Test Fails: HTTP Endpoint Not Accessible

**Cause:** Service not running or Traefik routing issue

**Solution:**

```bash
# Check Traefik logs
docker logs traefik

# Verify DNS resolution
nslookup <service>.<domain>

# Test direct container access
docker exec -it <container-name> curl -sf http://localhost:<port>/health
```

### Test Fails: OAuth Configuration Missing

**Cause:** `setup-authentik.sh` not run

**Solution:**

```bash
# Run OIDC provider setup
./scripts/setup-authentik.sh

# Verify .env contains client credentials
grep OAUTH_CLIENT .env
```

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Test SSO Integration

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Start stacks
        run: |
          cp .env.example .env
          docker compose -f docker-compose.base.yml up -d
          docker compose -f stacks/sso/docker-compose.yml up -d
      - name: Wait for healthy
        run: sleep 120
      - name: Run SSO tests
        run: ./tests/test-sso-integration.sh
```

## License

MIT License
