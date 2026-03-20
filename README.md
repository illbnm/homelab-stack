# HomeLab Stack Integration Testing Suite

This repository contains a comprehensive integration testing suite for the HomeLab Stack project.

## Overview

The testing suite provides automated verification of all services in the HomeLab Stack, ensuring:

- Container health and startup status
- HTTP endpoint availability
- Service interconnectivity
- Configuration integrity
- SSO flow (if applicable)

## Features

- **Level 1 Tests**: Container health checks
- **Level 2 Tests**: HTTP endpoint verification
- **Level 3 Tests**: Service interconnectivity testing
- **Level 4 Tests**: SSO flow testing (if applicable)
- **Level 5 Tests**: Configuration integrity checks

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/illbnm/homelab-stack.git
   cd homelab-stack
   ```

2. Run the tests:
   ```bash
   ./tests/run-tests.sh run base --json
   ```

3. View results:
   ```bash
   cat tests/results/report.json
   ```

## Test Structure

```
homelab-stack/
├── tests/
│   ├── run-tests.sh          # Test runner
│   ├── lib/
│   │   └── assert.sh          # Assertion library
│   ├── stacks/
│   │   ├── base.test.sh       # Base stack tests
│   │   ├── http.test.sh       # HTTP endpoint tests
│   │   └── config.test.sh     # Configuration tests
│   ├── e2e/                 # End-to-end tests
│   └── results/              # Test results
└── feature-tests.sh        # Feature implementation
```

## Available Tests

### Base Stack Tests (`tests/stacks/base.test.sh`)
- Container health checks for Traefik, Portainer, Watchtower
- API endpoint verification

### HTTP Endpoint Tests (`tests/stacks/http.test.sh`)
- HTTP 200 status checks for all web services
- API endpoint verification

### Configuration Tests (`tests/stacks/config.test.sh`)
- Compose file syntax validation
- Healthcheck verification
- Latest tag detection

## Usage

### Run All Tests
```bash
./tests/run-tests.sh run base
```

### Run with JSON Output
```bash
./tests/run-tests.sh run base --json
```

### Run All Stacks
```bash
./tests/run-tests.sh run all
```

## Assertion Library

The test suite includes a comprehensive assertion library (`tests/lib/assert.sh`) with functions like:

- `assert_container_running` - Check if container is running
- `assert_container_healthy` - Check if container is healthy
- `assert_http_200` - Verify HTTP 200 response
- `assert_json_value` - Validate JSON values
- `assert_file_contains` - Check file contents
- And many more...

## Requirements

- Docker and Docker Compose
- curl, jq
- Bash shell

## Contributing

1. Add new test files to `tests/stacks/`
2. Use the assertion library for consistency
3. Update `tests/run-tests.sh` to include new tests
4. Ensure all tests pass before submitting PR

## License

See LICENSE file in the repository.

---

**Note**: This testing suite was implemented as part of a $200 bounty for the HomeLab Stack project.