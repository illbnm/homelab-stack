# 🧪 HomeLab Stack — Integration Tests

> Automated integration test suite for all HomeLab stacks.

## Quick Start

```bash
# Run tests for a specific stack
./tests/run-tests.sh --stack base

# Run all tests
./tests/run-tests.sh --all

# Run with JSON report
./tests/run-tests.sh --all --json
```

## Architecture

```
tests/
├── run-tests.sh              # Test runner entry point
├── lib/
│   ├── assert.sh             # Assertion library
│   ├── docker.sh             # Docker helper functions
│   └── report.sh             # Test reporting (terminal + JSON)
├── stacks/
│   ├── base.test.sh          # Traefik + Portainer + Watchtower
│   ├── media.test.sh         # Jellyfin + Sonarr + Radarr + qBittorrent
│   ├── monitoring.test.sh    # Prometheus + Grafana + Loki
│   ├── sso.test.sh           # Authentik SSO
│   ├── databases.test.sh     # PostgreSQL + Redis + MariaDB
│   ├── notifications.test.sh # ntfy + Apprise
│   ├── network.test.sh       # AdGuard + WireGuard + NPM
│   ├── productivity.test.sh  # Gitea + Vaultwarden
│   ├── storage.test.sh       # Nextcloud + MinIO
│   └── ai.test.sh            # Ollama + Open WebUI
├── e2e/
│   └── sso-flow.test.sh      # SSO end-to-end flow
├── ci/
│   └── docker-compose.test.yml  # CI-optimized compose
└── results/                  # Test output (gitignored)
    └── report.json
```

## Test Runner

```bash
./tests/run-tests.sh [OPTIONS]

Options:
  --stack <name>   Run tests for a specific stack
  --all            Run all stack tests
  --json           Generate JSON report
  --help           Show help
```

## Assertion Library

The `tests/lib/assert.sh` library provides these assertions:

| Function | Description |
|----------|-------------|
| `assert_eq ACTUAL EXPECTED [MSG]` | Equality check |
| `assert_not_empty VALUE [MSG]` | Non-empty string |
| `assert_exit_code EXPECTED [MSG]` | Last command exit code |
| `assert_container_running NAME` | Docker container running |
| `assert_container_healthy NAME [TIMEOUT]` | Container healthy (waits) |
| `assert_http_200 URL [TIMEOUT]` | HTTP 2xx response |
| `assert_http_response URL PATTERN` | Response body matches pattern |
| `assert_json_value JSON JQ_PATH EXPECTED` | jq value check |
| `assert_json_key_exists JSON JQ_PATH` | jq key exists (non-null) |
| `assert_file_contains FILE PATTERN` | File content grep |

### Usage in Tests

Each `.test.sh` file sources the runner (which sources the libraries), so you
can call assertions directly:

```bash
#!/usr/bin/env bash
# my-stack.test.sh

assert_container_running my-service
assert_container_healthy my-service 30
assert_http_200 "http://localhost:8080/api/health" 10

# Custom inline test
test_start "My custom check"
if some_condition; then
  test_pass
else
  test_fail "reason"
fi
```

## Docker Helpers

`tests/lib/docker.sh` provides utility functions:

- `docker_is_running` — Check Docker daemon
- `container_exists NAME` — Container exists (any state)
- `container_is_running NAME` — Container is running
- `container_health NAME` — Get container health status
- `wait_for_container NAME [TIMEOUT]` — Wait for container to start
- `list_running_containers` — List all running containers

## CI / GitHub Actions

The `.github/workflows/test.yml` workflow runs on push/PR to master:

1. **ShellCheck** — Lint all shell scripts
2. **Integration Tests** — Start CI compose, run test suite, upload report

### CI Docker Compose

`tests/ci/docker-compose.test.yml` provides a lightweight subset for CI:
- Traefik (reverse proxy)
- ntfy + Apprise (notifications)

This avoids pulling heavy images (Jellyfin, Prometheus, etc.) in CI while
still validating the test framework end-to-end.

## JSON Report

When using `--json`, a report is written to `tests/results/report.json`:

```json
{
  "timestamp": "2026-03-24T15:00:00Z",
  "status": "pass",
  "duration_seconds": 42,
  "results": {
    "passed": 25,
    "failed": 0,
    "skipped": 3,
    "total": 28
  },
  "failures": []
}
```

## Adding Tests for a New Stack

1. Create `tests/stacks/<name>.test.sh`
2. Use assertions from the library
3. The runner auto-discovers `*.test.sh` files in `tests/stacks/`
4. Add the stack name to `usage()` in `run-tests.sh`

## Requirements

- Bash 4+
- Docker + Docker Compose
- `curl`, `jq`, `grep`
- Optional: `nc` / `netcat` for port checks
