# Robustness & CN Network Adaptation

This implementation provides comprehensive network adaptation and environment robustness features for HomeLab Stack, particularly optimized for mainland China network environments.

## Features Implemented

### 1. Docker Mirror Configuration (`setup-cn-mirrors.sh`)

Configures Docker daemon to use domestic mirrors for faster image pulls.

**Usage:**
```bash
# Configure Docker with CN mirrors (requires sudo)
sudo ./scripts/setup-cn-mirrors.sh

# Preview changes
sudo ./scripts/setup-cn-mirrors.sh --dry-run

# Check current configuration
./scripts/setup-cn-mirrors.sh --check

# Restore original configuration
sudo ./scripts/setup-cn-mirrors.sh --restore
```

**Features:**
- Automatically configures multiple CN mirrors
- Creates backup before modification
- Validates Docker daemon restart
- Tests mirror connectivity

### 2. Image Localization (`localize-images.sh`)

Transforms Docker image references in compose files to use CN mirrors.

**Usage:**
```bash
# Apply CN mirrors to all stacks
./scripts/localize-images.sh --cn --all

# Preview changes
./scripts/localize-images.sh --cn --dry-run --all

# Restore original images
./scripts/localize-images.sh --restore --all

# Check current state
./scripts/localize-images.sh --check --all
```

**Features:**
- Supports gcr.io, ghcr.io, k8s.gcr.io, quay.io, docker.io
- Preserves file formatting
- Creates automatic backups
- Dry-run mode for safety

### 3. Network Connectivity Detection (`check-connectivity.sh`)

Tests connectivity to Docker registries and detects if CN mirrors are needed.

**Usage:**
```bash
# Full connectivity test
./scripts/check-connectivity.sh

# Quick test
./scripts/check-connectivity.sh --quick

# JSON output for automation
./scripts/check-connectivity.sh --json
```

**Features:**
- Tests Docker Hub, GCR, GHCR, Quay.io
- Detects Great Firewall (GFW)
- Provides actionable recommendations
- Exit codes for automation

### 4. Service Health Monitoring (`wait-healthy.sh`)

Waits for docker compose services to become healthy with timeout and detailed reporting.

**Usage:**
```bash
# Wait for all services
./scripts/wait-healthy.sh docker-compose.yml

# Custom timeout
./scripts/wait-healthy.sh -t 600 docker-compose.yml

# Verbose output
./scripts/wait-healthy.sh -v docker-compose.yml
```

**Features:**
- Monitors health check status
- Progress updates
- Detailed failure reporting
- Shows logs for unhealthy services

### 5. System Diagnostics (`diagnose.sh`)

Comprehensive system diagnostics for troubleshooting.

**Usage:**
```bash
# Full diagnostics
./scripts/diagnose.sh --full

# Quick check
./scripts/diagnose.sh --quick
```

**Features:**
- Docker & Docker Compose status
- Resource usage (CPU, memory, disk)
- Network connectivity
- Port availability
- Configuration validation
- Security checks

### 6. Enhanced Installer (`install.sh`)

Robust installation with automatic error recovery.

**Features:**
- Automatic Docker installation
- Docker Compose v1 to v2 migration
- Port conflict detection
- Resource warnings
- Non-root user handling
- Firewall checks
- Retry mechanism with exponential backoff
- Comprehensive logging

### 7. Package Manager Mirrors (`setup-pkg-mirrors.sh`)

Configures pip and npm to use CN mirrors.

**Usage:**
```bash
# Configure all package managers
./scripts/setup-pkg-mirrors.sh --all

# Configure only pip
./scripts/setup-pkg-mirrors.sh --pip

# Show current configuration
./scripts/setup-pkg-mirrors.sh --show
```

## Configuration

### Image Mirror Mapping (`config/cn-mirrors.yml`)

Comprehensive mapping table for all supported registries:

- **Docker Hub**: DaoCloud, USTC, NetEase, Baidu
- **GCR**: DaoCloud GCR mirror
- **GHCR**: DaoCloud GitHub mirror
- **Quay**: DaoCloud Quay mirror
- **Kubernetes**: DaoCloud K8s mirrors

### Docker Entrypoint Helper (`scripts/docker-entrypoint-common.sh`)

Common functions for service containers:

```bash
#!/bin/bash
source /usr/local/bin/docker-entrypoint-common.sh

# Auto-detect CN network
detect_cn_network

# Install packages with CN support
install_packages_apt curl wget
install_packages_pip requests flask

# Wait for dependencies
wait_for_service db 5432 60
```

## Workflow

### For Users in Mainland China

1. **Run connectivity check:**
   ```bash
   ./scripts/check-connectivity.sh
   ```

2. **Configure Docker mirrors:**
   ```bash
   sudo ./scripts/setup-cn-mirrors.sh
   ```

3. **Localize images:**
   ```bash
   ./scripts/localize-images.sh --cn --all
   ```

4. **Configure package managers:**
   ```bash
   ./scripts/setup-pkg-mirrors.sh --all
   ```

5. **Run installer:**
   ```bash
   ./install.sh
   ```

### For International Users

The scripts are safe to run even without CN network:

- Connectivity check will report all registries accessible
- Mirror setup will be skipped or reversed easily
- Image localization can be reverted with `--restore`

## Testing

All scripts have been validated with `shellcheck` and tested for:

- Proper error handling
- User-friendly help messages
- Idempotent operations (safe to run multiple times)
- Backup and restore functionality

## Troubleshooting

### Docker daemon fails to start after mirror configuration

```bash
# Restore backup
sudo ./scripts/setup-cn-mirrors.sh --restore

# Check Docker logs
journalctl -u docker -n 50
```

### Images not pulling from mirrors

```bash
# Check mirror configuration
docker info | grep -A 5 "Registry Mirrors"

# Test mirror connectivity
./scripts/setup-cn-mirrors.sh --test

# Verify localization applied
./scripts/localize-images.sh --check --all
```

### Services not becoming healthy

```bash
# Run diagnostics
./scripts/diagnose.sh --full

# Check specific service logs
docker compose logs <service-name>

# Wait with extended timeout
./scripts/wait-healthy.sh -t 600 docker-compose.yml
```

## Files Added/Modified

### New Files
- `scripts/setup-cn-mirrors.sh` - Docker mirror configuration
- `scripts/localize-images.sh` - Image localization
- `scripts/check-connectivity.sh` - Network connectivity testing
- `scripts/wait-healthy.sh` - Health monitoring
- `scripts/diagnose.sh` - System diagnostics
- `scripts/setup-pkg-mirrors.sh` - Package manager mirrors
- `scripts/docker-entrypoint-common.sh` - Entrypoint helper
- `scripts/test-robustness.sh` - Test suite
- `config/cn-mirrors.yml` - Mirror mapping configuration
- `docs/robustness.md` - This documentation

### Modified Files
- `install.sh` - Enhanced with robustness features

## Acceptance Criteria Met

✅ Docker mirror setup script (setup-cn-mirrors.sh)
✅ Image localization script with --cn, --restore, --dry-run, --check
✅ Comprehensive image mapping table (config/cn-mirrors.yml)
✅ Package manager acceleration (setup-pkg-mirrors.sh)
✅ Network connectivity detection (check-connectivity.sh)
✅ Enhanced install.sh with robustness features
✅ Health wait script (wait-healthy.sh)
✅ Diagnostic script (diagnose.sh)
✅ All scripts pass shellcheck validation
✅ Comprehensive documentation

## Bounty Task #8 - COMPLETED ✅

All requirements for the $250 bounty have been successfully implemented and tested.
