# Tests

Automated test suite for homelab-stack.

## Running Tests Locally

```bash
# All tests
bash tests/test-compose.sh
bash tests/test-env.sh
bash tests/test-network.sh
bash tests/test-backup.sh
bash tests/test-notifications.sh

# Or via Docker (recommended for CI)
docker run --rm -v $(pwd):/repo -w /repo ubuntu:24.04 bash tests/test-compose.sh
```

## Test Scripts

| Script | Purpose |
|--------|---------|
| `lib.sh` | Shared test utilities and assertion functions |
| `test-compose.sh` | Validates all docker-compose.yml files |
| `test-env.sh` | Validates environment variable documentation |
| `test-network.sh` | Validates network configuration across stacks |
| `test-backup.sh` | Tests backup/restore scripts |
| `test-notifications.sh` | Tests notification stack (ntfy, apprise) |

## CI

Tests run automatically on push/PR via `.github/workflows/ci.yml`.
