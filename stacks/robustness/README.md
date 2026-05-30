# Robustness Stack — Environment Hardening & CN Network

This stack provides scripts and configuration for making HomeLab Stack
deployable in any network environment, especially mainland China.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-cn-mirrors.sh` | Configure Docker mirror accelerators |
| `scripts/localize-images.sh` | Replace gcr.io/ghcr.io with CN mirrors |
| `scripts/check-connectivity.sh` | Network reachability diagnostics |
| `scripts/wait-healthy.sh` | Wait for containers to become healthy |
| `scripts/diagnose.sh` | Full system diagnostics report |
| `install.sh` | Robust installation with error handling |

## Quick Start

```bash
# Check connectivity
./scripts/check-connectivity.sh

# If behind GFW, setup mirrors
./scripts/setup-cn-mirrors.sh

# Localize images
./scripts/localize-images.sh --cn
```

## Architecture

All scripts handle:
- Network failures with retry (exponential backoff)
- Missing dependencies (auto-install Docker if missing)
- Port conflicts and resource warnings
- Non-root user detection
