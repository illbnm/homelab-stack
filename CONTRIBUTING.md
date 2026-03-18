# Contributing to HomeLab Stack

## Testing Requirements

Every new stack PR **must** include corresponding integration tests.

### Adding Tests for a New Stack

1. Create `tests/stacks/<stack-name>.test.sh`
2. Define `test_*()` functions following the naming convention
3. Run locally before submitting:

```bash
# Verify your tests are discovered
./tests/run-tests.sh --dry-run --verbose

# Run tests for your stack (requires stack to be running)
./tests/run-tests.sh --stack <stack-name> --json
```

### Test Structure

Each test function should use the assertion library (`tests/lib/assert.sh`):

```bash
#!/usr/bin/env bash

test_myservice_running() {
  assert_container_running "myservice"
}

test_myservice_healthy() {
  assert_container_healthy "myservice"
}

test_myservice_api() {
  assert_http_200 "http://localhost:PORT/health" 10
}

test_myservice_no_crash_loop() {
  assert_no_crash_loop "myservice" 3
}
```

### Required Test Levels

| Level | What to Test | Example |
|-------|-------------|---------|
| L1 | Container running + healthy | `assert_container_running`, `assert_container_healthy` |
| L2 | HTTP endpoints respond | `assert_http_200`, `assert_http_status` |
| L3 | Inter-service connectivity | Prometheus → cAdvisor, Grafana → Prometheus |

### Available Assertions

See `tests/lib/assert.sh` for the full list:

- **Container:** `assert_container_running`, `assert_container_healthy`, `assert_no_crash_loop`
- **HTTP:** `assert_http_200`, `assert_http_status`, `assert_http_body_contains`
- **JSON:** `assert_json_value`, `assert_json_key_exists`, `assert_http_json_value`
- **Docker:** `assert_volume_exists`, `assert_network_exists`, `assert_container_in_network`
- **Logs:** `assert_log_contains`, `assert_log_no_errors`
- **General:** `assert_eq`, `assert_not_empty`, `assert_command_succeeds`

### Running All Tests

```bash
# All stacks
./tests/run-tests.sh --all --json --junit

# Specific stacks
./tests/run-tests.sh --stack base,monitoring

# See available options
./tests/run-tests.sh --help
```

### CI

Tests run automatically via GitHub Actions on PRs that modify `stacks/`, `scripts/`, or `tests/`. See `.github/workflows/test.yml`.
