# 🧪 HomeLab Stack - Testing Framework

> Comprehensive testing suite for validation, integration, and end-to-end deployment verification.

## 📋 Overview

This testing framework provides three levels of testing:

| Level | Purpose | Location | Runtime |
|-------|---------|----------|---------|
| **Unit Tests** | Configuration validation, YAML syntax, best practices | `tests/unit/` | ~30s |
| **Integration Tests** | Service connectivity, health checks, port availability | `tests/integration/` | ~2-5min |
| **E2E Tests** | Full deployment workflow, cleanup, persistence | `tests/e2e/` | ~10-15min |

## 🚀 Quick Start

### Run All Tests

```bash
# Make scripts executable
chmod +x tests/**/*.sh

# Run all test suites
./scripts/run-all-tests.sh
```

### Run Individual Test Suites

```bash
# Unit tests only (fast, no Docker required)
./tests/unit/test-config-validation.sh

# Integration tests (requires running services)
./tests/integration/test-services.sh

# E2E tests (full deployment cycle)
./tests/e2e/test-deployment.sh
```

## 📁 Test Structure

```
tests/
├── README.md                      # This file
├── run-all-tests.sh              # Master test runner
│
├── unit/                         # Unit tests
│   ├── test-config-validation.sh # Config & YAML validation
│   └── test-best-practices.sh    # Best practices checks
│
├── integration/                  # Integration tests
│   ├── test-services.sh          # Service connectivity
│   └── test-network.sh           # Network & firewall
│
└── e2e/                          # End-to-end tests
    ├── test-deployment.sh        # Full deployment workflow
    └── test-backup-restore.sh    # Backup & restore cycle
```

## 🧪 Test Suites

### Unit Tests

**Purpose**: Validate configuration files without running services.

**Tests include**:
- ✅ `.env.example` validation
- ✅ Required environment variables
- ✅ YAML syntax validation
- ✅ Traefik configuration checks
- ✅ Docker image tag validation (no `latest`)
- ✅ Health check definitions
- ✅ Network configuration
- ✅ Volume definitions

**Run**:
```bash
./tests/unit/test-config-validation.sh
```

**Requirements**: None (can run without Docker)

---

### Integration Tests

**Purpose**: Verify running services are healthy and accessible.

**Tests include**:
- ✅ Container status & health
- ✅ HTTP endpoint availability
- ✅ TCP port accessibility
- ✅ Docker network connectivity
- ✅ Volume mounts
- ✅ Log file accessibility
- ✅ Inter-service communication

**Stacks tested**:
- Base Infrastructure (Traefik, Portainer, Watchtower)
- SSO Stack (Authentik)
- Monitoring Stack (Prometheus, Grafana, Loki, Alertmanager)
- Database Stack (PostgreSQL, Redis, MariaDB)
- Media Stack (Jellyfin, Sonarr, Radarr, qBittorrent)
- Productivity Stack (Gitea, Vaultwarden)
- Network Stack (AdGuard, Nginx Proxy Manager, WireGuard)
- Storage Stack (Nextcloud, MinIO, FileBrowser)
- AI Stack (Ollama, Open WebUI)
- Home Automation (Home Assistant, Node-RED, Mosquitto)
- Notifications (ntfy, Gotify)
- Dashboard (Homepage)

**Run**:
```bash
# Deploy base stack first
docker compose -f stacks/base/docker-compose.yml up -d

# Run integration tests
./tests/integration/test-services.sh
```

**Requirements**: 
- Docker daemon running
- Services deployed and running

---

### E2E Tests

**Purpose**: Full deployment workflow from scratch.

**Tests include**:
- ✅ Environment setup
- ✅ Pre-flight checks (Docker, Compose, ports)
- ✅ Network creation
- ✅ Base stack deployment
- ✅ Health verification
- ✅ Log verification
- ✅ Configuration persistence
- ✅ Cleanup

**Run**:
```bash
./tests/e2e/test-deployment.sh
```

**Requirements**:
- Docker daemon running
- Sudo/root privileges for network creation
- Ports 80/443 available

---

## 🔧 CI/CD Integration

### GitHub Actions

Tests automatically run on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Workflow file**: `.github/workflows/ci.yml`

**Jobs**:
1. **Lint** - YAML validation, shell syntax, `latest` tag check
2. **Unit Tests** - Configuration validation
3. **Integration Tests** - Service connectivity (Docker-in-Docker)
4. **E2E Tests** - Full deployment (optional, manual trigger)
5. **Security Scan** - Trivy vulnerability scan
6. **Docs Check** - README, markdown links

**Manual E2E trigger**:
```bash
# Go to Actions tab → CI/CD Pipeline → Run workflow
# Select "Run E2E tests: true"
```

---

## 📊 Test Results

### Output Format

```
========================================
  Integration Tests - Service Connectivity
========================================

[Base Infrastructure]
  ✓ Container traefik is running (healthy)
  ✓ Container portainer is running (healthy)
  ✓ Container watchtower is running (no-healthcheck)
  ✓ Network 'proxy' exists
  ✓ Traefik-HTTP port 80@localhost is open
  ✓ Traefik-HTTPS port 443@localhost is open

========================================
  Results: 42 passed | 3 failed | 5 skipped
========================================
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All tests passed |
| `1` | One or more tests failed |

---

## 🛠️ Writing New Tests

### Test Template

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

test_example() {
  log_group "Example Tests"
  
  if [[ condition ]]; then
    log_pass "Test description"
  else
    log_fail "Test description"
  fi
}

main() {
  test_example
  
  echo ""
  echo "Results: $PASSED passed | $FAILED failed"
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
```

### Best Practices

1. **Use helper functions**: `log_pass`, `log_fail`, `log_skip`
2. **Group related tests**: Use `log_group` for sections
3. **Handle failures gracefully**: Don't `exit 1` immediately
4. **Support offline mode**: Skip tests if services aren't running
5. **Timeout long operations**: Use `--connect-timeout` for HTTP checks
6. **Clean up resources**: Remove networks/volumes in cleanup phase

---

## 🐛 Troubleshooting

### Common Issues

**1. Permission denied on Docker commands**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**2. Port already in use**
```bash
# Check what's using the port
sudo lsof -i :80
sudo netstat -tuln | grep :80

# Stop conflicting service
sudo systemctl stop nginx
```

**3. Network already exists**
```bash
# Remove and recreate
docker network rm proxy
docker network create proxy
```

**4. Tests timeout**
```bash
# Increase timeout in test script
# Look for: --connect-timeout 5
# Change to: --connect-timeout 10
```

**5. Services not starting**
```bash
# Check logs
docker logs traefik
docker logs portainer

# Validate config
docker compose -f stacks/base/docker-compose.yml config
```

---

## 📈 Coverage Goals

| Component | Unit | Integration | E2E |
|-----------|------|-------------|-----|
| Configuration | ✅ | - | ✅ |
| Traefik | ✅ | ✅ | ✅ |
| Portainer | ✅ | ✅ | ✅ |
| Watchtower | ✅ | ✅ | ✅ |
| Authentik | ✅ | ✅ | ✅ |
| Prometheus | ✅ | ✅ | ✅ |
| Grafana | ✅ | ✅ | ✅ |
| Databases | ✅ | ✅ | ✅ |
| Media Stack | ✅ | ✅ | ✅ |
| Network | ✅ | ✅ | ✅ |

---

## 📝 Test Maintenance

### When to Update Tests

- ✅ New service added to a stack
- ✅ Port numbers changed
- ✅ New environment variables required
- ✅ Health check endpoints modified
- ✅ Network configuration changed

### Review Schedule

- **Weekly**: Check for failing tests in CI
- **Monthly**: Review test coverage
- **Per PR**: Ensure tests pass before merge

---

## 🎯 Acceptance Criteria

For the Testing Framework bounty task:

- ✅ Unit tests for configuration validation
- ✅ Integration tests for all service stacks
- ✅ E2E tests for deployment workflow
- ✅ GitHub Actions CI/CD pipeline
- ✅ Test documentation (this file)
- ✅ All tests passing locally
- ✅ All tests passing in CI

---

## 📚 Related Documentation

- [Main README](../README.md) - Project overview
- [BOUNTY.md](../BOUNTY.md) - Bounty task list
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [CI/CD Workflow](../.github/workflows/ci.yml) - Pipeline configuration

---

**Maintained by**: HomeLab Stack Team  
**Last Updated**: 2026-03-22
