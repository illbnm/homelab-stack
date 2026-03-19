# 🧪 Testing Framework

> End-to-end and integration tests for the HomeLab Stack.

## Overview

This directory contains automated tests for all stacks in the HomeLab Stack project. Tests validate Docker Compose configurations, service health, HTTP endpoints, and environment setup.

## Directory Structure

```
tests/
├── run-tests.sh          ← Main test runner (all stacks or specific stack)
├── README.md             ← This file
├── lib/                  ← Shared test utilities
│   ├── assert.sh         ← Assertion helpers (assert_eq, assert_contains, etc.)
│   └── docker.sh         ← Docker container helpers (health, logs, HTTP)
├── stacks/               ← Per-stack integration tests
│   ├── base.test.sh
│   ├── ai.test.sh
│   ├── databases.test.sh
│   ├── home-automation.test.sh
│   ├── media.test.sh
│   ├── monitoring.test.sh
│   ├── network.test.sh
│   ├── notifications.test.sh
│   ├── productivity.test.sh
│   ├── sso.test.sh
│   └── storage.test.sh
├── e2e/                  ← End-to-end cross-stack workflow tests (TBD)
├── ci/                   ← CI/CD pipeline test configs (TBD)
└── results/              ← Test results (JSON format)
```

## Quick Start

### Run all tests

```bash
cd tests
./run-tests.sh --all
```

### Run tests for a specific stack

```bash
./run-tests.sh --stack ai
./run-tests.sh --stack media
./run-tests.sh --stack base
```

### Run with JSON output

```bash
./run-tests.sh --all --json
# Results saved to results/test-results-<timestamp>.json
```

### Dry run (show tests without executing)

```bash
./run-tests.sh --stack base --dry-run
```

## Test Coverage

| Stack | Tests | Coverage |
|-------|-------|----------|
| Base (Traefik + Portainer) | 107 lines | Traefik API, Portainer, Watchtower, network |
| Monitoring | 66 lines | Prometheus, Grafana, Loki, Alertmanager, exporters |
| Media | 61 lines | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent |
| SSO / Authentik | 45 lines | Authentik OIDC, outpost, user sync |
| Storage | 45 lines | Nextcloud, MinIO, FileBrowser, PostgreSQL |
| Home Automation | 28 lines | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT |
| Productivity | 28 lines | Gitea, Vaultwarden, Outline, BookStack |
| AI | 21 lines | Ollama, Open WebUI, Stable Diffusion |
| Databases | 21 lines | PostgreSQL, Redis, MariaDB |
| Network | 22 lines | AdGuard, Nginx Proxy Manager |
| Notifications | 15 lines | NTFY, Apprise |

**Total: 459 lines of stack tests + 638 lines of framework code = 1,097 lines total**

## Test Types

### Stack-Level Integration Tests
Each `stacks/<name>.test.sh` validates:
- **Container running**: service container exists and is running
- **Health check**: Docker healthcheck passes within timeout
- **HTTP endpoint**: web UI or API responds with expected status code
- **Compose validation**: docker-compose.yml is valid and parseable
- **Network configuration**: required Docker networks exist
- **Volume mounts**: required volumes are created

### Example test (from base.test.sh)

```bash
test_traefik_healthy() {
  assert_container_healthy "traefik" 60
}

test_traefik_api_version() {
  local code
  code=$(http_status "http://localhost:80/api/version" 5)
  assert_eq "$code" "200"
}
```

## CI/CD Integration

### GitHub Actions

To add CI tests, create `.github/workflows/test.yml`:

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start stacks
        run: |
          docker compose -f stacks/base/docker-compose.yml up -d
          docker compose -f stacks/databases/docker-compose.yml up -d
      - name: Run tests
        run: ./tests/run-tests.sh --all --json
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: tests/results/*.json
```

### Local CI simulation

```bash
# Run tests with verbose output
VERBOSE=true ./run-tests.sh --all

# Run with custom timeout
TIMEOUT=120 ./run-tests.sh --stack media
```

## Writing New Tests

### Add tests for a new stack

1. Create `tests/stacks/my-new-stack.test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_service_running() {
  assert_container_running "my-service"
}

test_service_http() {
  assert_http_200 "http://localhost:8080/health" 30
}

test_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/my-new-stack/docker-compose.yml"
}
```

2. Add to `run-tests.sh` stack list:

```bash
STACKS="base ai databases home-automation media monitoring network notifications productivity sso storage my-new-stack"
```

3. Run to verify:

```bash
./run-tests.sh --stack my-new-stack
```

### Using assertion helpers

```bash
# Numeric comparison
assert_eq "$actual" "200" "status code"

# String contains
assert_contains "healthy running" "$container_status"

# Not empty
assert_not_empty "$logs" "container logs"

# HTTP status
code=$(http_status "http://localhost:8080/health" 10)
assert_eq "$code" "200"
```

## Test Results

Results are saved to `results/test-results-<timestamp>.json`:

```json
{
  "timestamp": "2026-03-18T12:00:00Z",
  "stack": "base",
  "passed": 8,
  "failed": 0,
  "skipped": 2,
  "duration_seconds": 45,
  "tests": [
    {
      "name": "test_traefik_healthy",
      "status": "passed",
      "duration_ms": 1200
    }
  ]
}
```

## Known Limitations

- Tests require running Docker daemon and locally deployed stacks
- Tests run against `localhost` — not suitable for remote deployment testing
- e2e/ and ci/ directories are templates for future enhancement
- Some tests may be flaky due to timing (services take time to start)
