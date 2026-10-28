# 🧪 HomeLab Stack Automated Integration Testing Suite

Automated verification framework covering container orchestration, endpoint health, inter-service networking, and end-to-end user journeys.

## 🚀 Usage
Run all test levels:
```bash
./tests/run-tests.sh --all
```

Run test suite for a specific stack:
```bash
./tests/run-tests.sh --stack base
```

## 🏗️ Structure
- `tests/lib/assert.sh`: Assertion library (`assert_eq`, `assert_http_200`, `assert_container_running`, `assert_json_value`).
- `tests/lib/docker.sh`: Docker inspection and port discovery helpers.
- `tests/lib/report.sh`: Colored CLI summary and JSON export (`test-report.json`).
- `tests/stacks/`: Per-stack test definitions (`base`, `media`, `storage`, `monitoring`, `network`, `productivity`, `ai`, `sso`, `databases`, `notifications`).
- `tests/e2e/`: End-to-end simulations (`sso-flow.test.sh`, `backup-restore.test.sh`).
- `tests/ci/`: Minimal CI compose definitions.
