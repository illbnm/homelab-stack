# Integration Testing Framework

Automated test harness providing end-to-end integration validation across all services in HomeLab Stack.

## Capabilities

- **Syntax & Schema Verification**: Automatically verifies syntax for all `docker-compose.yml` declarations.
- **Image Pinning Safeguards**: Enforces strict tag versioning preventing unpinned `:latest` deployment risks.
- **Assertion Engine (`tests/lib/assert.sh`)**: Built-in primitives for container health, HTTP endpoints, JSON API payloads, and response patterns.
- **Dual Reporting**: Real-time ANSI colored terminal output plus structured JSON export (`tests/results/report.json`).
- **CI / CD Pipeline**: GitHub Actions integration workflow running on every PR and commit.

## Usage

```bash
# Run all tests
bash tests/run-tests.sh --all

# Run specific stack
bash tests/run-tests.sh --stack base

# Export JSON metrics for CI
bash tests/run-tests.sh --all --json
```
